import tensorflow as tf

def repeat(x, num_repeats):
    with tf.name_scope("repeat"):
        ones = tf.ones((1, num_repeats), dtype='int32')
        x = tf.reshape(x, shape=(-1,1))
        x = tf.matmul(x, ones)
        return tf.reshape(x, [-1])

def interpolate(image, x, y, output_size):
    with tf.name_scope("interpolate"):
        batch_size = tf.shape(image)[0]
        height = tf.shape(image)[1]
        width = tf.shape(image)[2]
        num_channels = tf.shape(image)[3]

        x = tf.cast(x , dtype='float32')
        y = tf.cast(y , dtype='float32')

        height_float = tf.cast(height, dtype='float32')
        width_float = tf.cast(width, dtype='float32')

        output_height = output_size[0]
        output_width  = output_size[1]

        x = .5*(x + 1.0)*(width_float)
        y = .5*(y + 1.0)*(height_float)

        x0 = tf.cast(tf.floor(x), 'int32')
        x1 = x0 + 1
        y0 = tf.cast(tf.floor(y), 'int32')
        y1 = y0 + 1

        max_y = tf.cast(height - 1, dtype='int32')
        max_x = tf.cast(width - 1,  dtype='int32')
        zero = tf.zeros([], dtype='int32')

        x0 = tf.clip_by_value(x0, zero, max_x)
        x1 = tf.clip_by_value(x1, zero, max_x)
        y0 = tf.clip_by_value(y0, zero, max_y)
        y1 = tf.clip_by_value(y1, zero, max_y)

        flat_image_dimensions = height*width
        pixels_batch = tf.range(batch_size)*flat_image_dimensions
        flat_output_dimensions = output_height*output_width
        base = repeat(pixels_batch, flat_output_dimensions)
        base_y0 = base + y0*width
        base_y1 = base + y1*width
        indices_a = base_y0 + x0
        indices_b = base_y1 + x0
        indices_c = base_y0 + x1
        indices_d = base_y1 + x1

        flat_image = tf.reshape(image, shape=(-1, num_channels))
        flat_image = tf.cast(flat_image, dtype='float32')
        pixel_values_a = tf.gather(flat_image, indices_a)
        pixel_values_b = tf.gather(flat_image, indices_b)
        pixel_values_c = tf.gather(flat_image, indices_c)
        pixel_values_d = tf.gather(flat_image, indices_d)

        x0 = tf.cast(x0, 'float32')
        x1 = tf.cast(x1, 'float32')
        y0 = tf.cast(y0, 'float32')
        y1 = tf.cast(y1, 'float32')

        area_a = tf.expand_dims(((x1 - x) * (y1 - y)), 1)
        area_b = tf.expand_dims(((x1 - x) * (y - y0)), 1)
        area_c = tf.expand_dims(((x - x0) * (y1 - y)), 1)
        area_d = tf.expand_dims(((x - x0) * (y - y0)), 1)
        output = tf.add_n([area_a*pixel_values_a,
                           area_b*pixel_values_b,
                           area_c*pixel_values_c,
                           area_d*pixel_values_d])
        return output

def meshgrid(height, width):
    with tf.name_scope("meshgrid"):
        y_linspace = tf.linspace(-1., 1., height)
        x_linspace = tf.linspace(-1., 1., width)
        x_coordinates, y_coordinates = tf.meshgrid(x_linspace, y_linspace)    
        y_coordinates = tf.expand_dims(tf.reshape(y_coordinates, [-1]),0)
        x_coordinates = tf.expand_dims(tf.reshape(x_coordinates, [-1]),0)
        indices_grid = tf.concat([x_coordinates, y_coordinates], 0)
        return indices_grid

def apply_transformation(flows, img, num_channels):
    with tf.name_scope("apply_transformation"):
        batch_size = tf.shape(img)[0]
        height = tf.shape(img)[1]
        width = tf.shape(img)[2]
        # num_channels = tf.shape(img)[3]
        output_size = (height, width)
        flow_channels = tf.shape(flows)[3]

        flows = tf.reshape(tf.transpose(flows, [0, 3, 1, 2]), [batch_size, flow_channels, height*width])

        indices_grid = meshgrid(height, width)

        transformed_grid = tf.add(flows, indices_grid)
        x_s = tf.slice(transformed_grid, [0, 0, 0], [-1, 1, -1])
        y_s = tf.slice(transformed_grid, [0, 1, 0], [-1, 1, -1])
        x_s_flatten = tf.reshape(x_s, [-1])
        y_s_flatten = tf.reshape(y_s, [-1])

        transformed_image = interpolate(img, x_s_flatten, y_s_flatten, (height, width))

        transformed_image = tf.reshape(transformed_image, [batch_size, height, width, num_channels])
        return transformed_image

def create_agl_map(inputs, height, width,feature_dims):
    with tf.name_scope("create_agl_map"):
        batch_size = tf.shape(inputs)[0]
        ret = tf.reshape(tf.tile(inputs,tf.constant([1,height*width])), [batch_size,height,width,feature_dims])
        return ret

def spatial_softmax_across_pixels(inputs):
    with tf.name_scope('spatial_softmax_across_pixels'):
        inputs = tf.cast(inputs, dtype = tf.float32)
        batch_size = tf.shape(inputs)[0]
        height = tf.shape(inputs)[1]
        width = tf.shape(inputs)[2]
        channels = tf.shape(inputs)[3]
        inputs = tf.reshape(tf.transpose(inputs, [0, 3, 1, 2]), [batch_size * channels, height * width])
        softmax_inputs = tf.nn.softmax(inputs)
        ret = tf.transpose(tf.reshape(softmax_inputs, [batch_size, channels, height, width]), [0, 2, 3, 1])
        return ret

def spatial_softmax_across_channels(inputs):
    with tf.name_scope("spatial_softmax_across_channels"):
        inputs = tf.cast(inputs, dtype = tf.float32)
        batch_size = tf.shape(inputs)[0]
        height = tf.shape(inputs)[1]
        width = tf.shape(inputs)[2]
        channels = tf.shape(inputs)[3]
        inputs = tf.reshape(inputs, [batch_size*height*width, channels])
        softmax_inputs = tf.nn.softmax(inputs)
        ret = tf.reshape(softmax_inputs, [batch_size, height, width, channels])
        return ret

def apply_light_weight(batch_img, light_weight):
    with tf.name_scope('apply_light_weight'):
        light_weight = spatial_softmax_across_channels(light_weight)
        img_wgts, pal_wgts = tf.expand_dims(light_weight[...,0],3), tf.expand_dims(light_weight[...,1],3)
        img_wgts = tf.concat([img_wgts, img_wgts, img_wgts], axis = 3)
        pal_wgts = tf.concat([pal_wgts, pal_wgts, pal_wgts], axis = 3)
        palette = tf.ones(tf.shape(batch_img), dtype = tf.float32)
        ret = tf.add(tf.multiply(batch_img, img_wgts), tf.multiply(palette, pal_wgts))
        return ret

def apply_light_weight_single(batch_img, light_weight):
    # perfrom softmax
    with tf.name_scope('apply_light_weight'):
        light_weight = spatial_softmax_across_pixels(light_weight)
        pal_wgts = light_weight
        img_wgts = tf.subtract(tf.ones(tf.shape(pal_wgts), dtype = tf.float32), pal_wgts)
        img_wgts = tf.concat([img_wgts, img_wgts, img_wgts], axis = 3)
        pal_wgts = tf.concat([pal_wgts, pal_wgts, pal_wgts], axis = 3)
        palette = tf.ones(tf.shape(batch_img), dtype = tf.float32)
        ret = tf.add(tf.multiply(batch_img, img_wgts), tf.multiply(palette, pal_wgts))
        return ret