#-*- coding: utf-8 -*-
import argparse

arg_lists = []
model_config = argparse.ArgumentParser()

# deepwarp parameters
model_config.add_argument('--eye'    , type=str, default='None'   , help='')
model_config.add_argument('--dataset', type=str, default='test_set', help='initial the input dataset')

# model parameters
model_config.add_argument('--is_cfw_only'    , type=bool, default=False, help='only use cfw module')
model_config.add_argument('--height'         , type=eval, default=41   , help='input image height')
model_config.add_argument('--width'          , type=eval, default=51   , help='input image width')
model_config.add_argument('--channel'        , type=eval, default=3    , help='inpit image channel')
model_config.add_argument('--ef_dim'         , type=eval, default=14   , help='# of channels of the eye anchor features')
model_config.add_argument('--agl_dim'        , type=eval, default=2    , help='# of length of angle difference')
model_config.add_argument('--encoded_agl_dim', type=eval, default=16   , help='# of dimension for encoding the angle difference')

# training parameters
model_config.add_argument('--lr'        , type=eval, default=0.0001   , help='initial the learning rate')
model_config.add_argument('--steps'     , type=eval, default=1250000  , help='initial total steps')
model_config.add_argument('--batch_size', type=eval, default=128      , help='initial the batch size')

# gpu ID ("0,1,3,5")
model_config.add_argument('--gpus', type=str, default='0', help='')

def get_config():
    config, unparsed = model_config.parse_known_args()
    print(config)
    return config, unparsed