from PIL import Image
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision.transforms as T
from fxpmath import Fxp

img = Image.open('./images/ney.jpg')

# Read Original image size
width, height = img.size

if width < height:
    sqrbound = width
else:
    sqrbound = height
# Setting the points for cropped image
left = 100
top = 0
right = sqrbound + left
bottom = sqrbound

imgcrop = img.crop((left, top, right, bottom))
# Image grayscaling
imgGray = imgcrop.convert('L')

newSize = (64, 64)
newImg = imgGray.resize(newSize)
newImg.save('./images/ney_resized.jpg')
newImg_arr = np.array(newImg)
newImg_arr32 = newImg_arr.astype(np.float32)
inputImage = torch.tensor(newImg_arr32)
print("\nInput Image: \n", inputImage)

# Convolution

kernel = torch.tensor([-0.0625, -0.125, -0.0625, -0.25, 1., -0.25, -
                      0.0625, -0.125, -0.0625]).reshape(3, 3).unsqueeze(0).unsqueeze(0)

bias = torch.tensor(-0.75).unsqueeze(0)
print("\nkernel:\n", kernel)
print("\nbias:\n", bias)

input = inputImage.unsqueeze(0).unsqueeze(0)

# Padding
m = nn.ReplicationPad2d(2)
pad_data = m(input)
print("\nPadding data result: \n", pad_data)

# Convolution
res = F.conv2d(pad_data, kernel, bias=bias, stride=1, padding=0, dilation=2)
print("\nConvolution result: \n", res)
relu_data = F.relu(res)
print("\nRelu result: \n",  relu_data)

transform = T.ToPILImage()
l0_result = transform(relu_data.squeeze().squeeze())
#l0_result.show()
l0_result.save('./images/ney_l0.jpg')

# MaxPooling
maxpoolRes = F.max_pool2d(relu_data, 2, stride=2, padding=0)
#print("\nMaxPooling result: \n", maxpoolRes)
l1_result = transform(maxpoolRes.squeeze().squeeze())
#l1_result.show()
l1_result.save('./images/ney_l1.jpg')

# Generate img.dat
ImagGray_flatten = newImg_arr32.flatten()
ImgData = Fxp(ImagGray_flatten, dtype='fxp-s13/4')
#print(ImagGray_flatten)
#print(ImgData.bin())
with open("./data/img.dat", 'w') as f:
    for row in ImgData:    
            f.write(str(row.bin()) + "      // data: " + str(row) + "\n")

# Generate layer0_golden.dat
l0_data_flatten = relu_data.numpy().flatten()
l0Data = Fxp(l0_data_flatten, dtype='fxp-s13/4')
#print(l0_data_flatten)
#print(l0Data.bin())
with open("./data/layer0_golden.dat", 'w') as f:
    for row in l0Data:    
            f.write(str(row.bin()) + "      // data: " + str(row) + "\n")

# Generate layer1_golden.dat
l1_data_flatten = maxpoolRes.numpy().flatten()
l1_data_flatten_ceil = np.ceil(l1_data_flatten)
l1Data = Fxp(l1_data_flatten_ceil, dtype='fxp-s13/4')
#print(l1_data_flatten_ceil)
#print(l1Data.bin())
with open("./data/layer1_golden.dat", 'w') as f:
    for row in l1Data:    
            f.write(str(row.bin()) + "      // data: " + str(row) + "\n")