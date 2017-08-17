import tensorflow as tf
import numpy as np

def batch_norm(x, n_out, train_phase, name="bn_layer"):
    with tf.variable_scope(name) as scope:
        batch_norm = tf.cond(train_phase, 
                lambda: tf.contrib.layers.batch_norm(x, is_training=True, reuse=None,scope=scope),
                lambda: tf.contrib.layers.batch_norm(x, is_training=False, reuse=True,scope=scope))
        return batch_norm