# Spatial transformer networks
Implementation of spatial transformer networks in keras 2.0 using tensorflow 1.0 as backend.

![alt tag](images/transformation.png)

![alt tag](images/results.jpg)

## Functional API usage

```python 
locnet = [Network]
locnet = Lambda(lambda x: spatial_transformer(affine_transformation=x,
                                              input_shape=input_img,
                                              output_size=(30,30)),
                output_shape = (30,30,1))(locnet)
```
This code is modified by silver from sources [oarriaga](https://github.com/oarriaga/spatial_transformer_networks) and [seya](https://github.com/EderSantana/seya/blob/master/examples/Spatial%20Transformer%20Networks.ipynb).