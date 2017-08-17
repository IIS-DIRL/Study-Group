import os
import tensorflow as tf

from tf_utils import *
from transformation import *
    
### define your inference model ###
def inference(input_img, input_fp, input_ang, phase_train, conf):
    """Build the Deepwarp model.
    Args: images, anchors_map of eye, angle 
    Returns: lcm images
    """
    corse_layer = {'depth':(16,32,32,32,2), 'filter_size':([5,5],[3,3],[3,3],[1,1],[1,1])}
    fine_layer  = {'depth':(16,32,32,32,2), 'filter_size':([5,5],[3,3],[3,3],[1,1],[1,1])}
    lcm_layer   = {'depth':(8,8,2)        , 'filter_size':([1,1],[1,1],[1,1])}
    '''agl encode module'''
    with tf.variable_scope('auto_encoder'):
        agl1 =  tf.nn.relu(tf.layers.dense(inputs=input_ang, units=16, activation=None, name='agl_encode_1'))
        agl2 =  tf.nn.relu(tf.layers.dense(inputs=agl1, units=16, activation=None, name='agl_encode_2'))
        agl3 =  tf.nn.relu(tf.layers.dense(inputs=agl2, units=conf.encoded_agl_dim, activation=None, name='agl_encode_3'))
        agl_map = create_agl_map(agl3, conf.height, conf.width, conf.encoded_agl_dim)

    corse_input = tf.concat([input_img,input_fp,agl_map], axis=3, name = 'corse_input')
    resized_input = tf.layers.max_pooling2d(inputs=corse_input, pool_size=[2, 2], strides=2, padding='same')
    '''coarse module'''
    with tf.variable_scope('coarse_module'):
        cn_0 = tf.layers.conv2d(inputs=resized_input, filters=corse_layer['depth'][0], kernel_size=corse_layer['filter_size'][0], padding='same', activation=None, use_bias=False, name='cn_0')
        cn_0_bn = tf.nn.relu(batch_norm(cn_0, corse_layer['depth'][0], phase_train, name= 'cn_0_bn'))
        cn_1 = tf.layers.conv2d(inputs=cn_0_bn, filters=corse_layer['depth'][1], kernel_size=corse_layer['filter_size'][1], padding='same', activation=None, use_bias=False, name='cn_1')
        cn_1_bn = tf.nn.relu(batch_norm(cn_1, corse_layer['depth'][1], phase_train, name= 'cn_1_bn'))
        cn_2 = tf.layers.conv2d(inputs=cn_1_bn, filters=corse_layer['depth'][2], kernel_size=corse_layer['filter_size'][2], padding='same', activation=None, use_bias=False, name='cn_2')
        cn_2_bn = tf.nn.relu(batch_norm(cn_2, corse_layer['depth'][2], phase_train, name= 'cn_2_bn'))
        cn_3 = tf.layers.conv2d(inputs=cn_2_bn, filters=corse_layer['depth'][3], kernel_size=corse_layer['filter_size'][3], padding='same', activation=None, use_bias=False, name='cn_3')
        cn_3_bn = tf.nn.relu(batch_norm(cn_3, corse_layer['depth'][3], phase_train, name= 'cn_3_bn'))
        cn_4 = tf.nn.tanh(tf.layers.conv2d(inputs=cn_3_bn, filters=corse_layer['depth'][4], kernel_size=corse_layer['filter_size'][4], padding='same', activation=None, use_bias=False, name='cn_4'))
        coarse_flow = tf.image.resize_images(cn_4, (conf.height, conf.width), method=tf.image.ResizeMethod.NEAREST_NEIGHBOR)

    coarse_img = apply_transformation(flows=coarse_flow, img=input_img, num_channels=3)
    fine_input = tf.concat([corse_input,coarse_img,coarse_flow],axis=3, name='fine_input')
    '''fine module'''
    with tf.variable_scope('fine_module'):
        fn_0 = tf.layers.conv2d(inputs=fine_input, filters=fine_layer['depth'][0], kernel_size=fine_layer['filter_size'][0], padding='same', activation=None, use_bias=False, name='fn_0')
        fn_0_bn = tf.nn.relu(batch_norm(fn_0, fine_layer['depth'][0], phase_train, name= 'fn_0_bn'))
        fn_1 = tf.layers.conv2d(inputs=fn_0_bn, filters=fine_layer['depth'][1], kernel_size=fine_layer['filter_size'][1], padding='same', activation=None, use_bias=False, name='fn_1')
        fn_1_bn = tf.nn.relu(batch_norm(fn_1, fine_layer['depth'][1], phase_train, name= 'fn_1_bn'))
        fn_2 = tf.layers.conv2d(inputs=fn_1_bn, filters=fine_layer['depth'][2], kernel_size=fine_layer['filter_size'][2], padding='same', activation=None, use_bias=False, name='fn_2')
        fn_2_bn = tf.nn.relu(batch_norm(fn_2, fine_layer['depth'][2], phase_train, name= 'fn_2_bn'))
        fn_3 = tf.layers.conv2d(inputs=fn_2_bn, filters=fine_layer['depth'][3], kernel_size=fine_layer['filter_size'][3], padding='same', activation=None, use_bias=False, name='fn_3')
        fn_3_bn = tf.nn.relu(batch_norm(fn_3, fine_layer['depth'][3], phase_train, name= 'fn_3_bn'))
        fine_flow = tf.nn.tanh(tf.layers.conv2d(inputs=fn_3_bn, filters=fine_layer['depth'][4], kernel_size=fine_layer['filter_size'][4], padding='same', activation=None, use_bias=False, name='fn_4'))

    flow = tf.add(coarse_flow, fine_flow, name = 'D')
    cfw_img = apply_transformation(flows = flow, img = input_img, num_channels=3)
    coarse_features = tf.image.resize_images(cn_3, (conf.height, conf.width), method=tf.image.ResizeMethod.NEAREST_NEIGHBOR)
    lcm_input = tf.concat([coarse_features,fn_3_bn], axis=3, name='lcm_input')
    '''lcm module'''
    with tf.variable_scope('lcm_module'):
        lcm_0 = tf.layers.conv2d(inputs=lcm_input, filters=lcm_layer['depth'][0], kernel_size=lcm_layer['filter_size'][0], padding='same', activation=None, use_bias=False, name='lcm_0')
        lcm_0_bn = tf.nn.relu(batch_norm(lcm_0, lcm_layer['depth'][0], phase_train, name= 'lcm_0_bn'))
        lcm_1 = tf.layers.conv2d(inputs=lcm_0_bn, filters=lcm_layer['depth'][1], kernel_size=lcm_layer['filter_size'][1], padding='same', activation=None, use_bias=False, name='lcm_1')
        lcm_1_bn = tf.nn.relu(batch_norm(lcm_1, lcm_layer['depth'][1], phase_train, name= 'lcm_1_bn'))
        lcm_2 = tf.layers.conv2d(inputs=lcm_1_bn, filters=lcm_layer['depth'][2], kernel_size=lcm_layer['filter_size'][2], padding='same', activation=None, use_bias=False, name='lcm_2')

    lcm_img = apply_light_weight(batch_img=cfw_img, light_weight=lcm_2)
    return lcm_img

### define your loss function ###
def loss(y_pred, y_):
    """Add Loss to all the trainable variables.
    Add summary for "Loss" and "Loss/avg".
    Args:
    y_pred: Logits from inference().
    y_: Labels from distorted_inputs or inputs()
    
    Returns:
    Loss tensor of type float.
    """
    # Calculate the average cross entropy loss across the batch.
    losses = tf.reduce_mean(tf.abs(y_pred - y_), axis=0)
        
    tf.add_to_collection('losses', losses)
    # The total loss is defined as the cross entropy loss plus all of the weight
    # decay terms (L2 loss).
    return tf.add_n(tf.get_collection('losses'), name='total_loss')