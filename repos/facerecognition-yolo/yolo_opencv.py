#############################################
# Object detection - YOLO - OpenCV
# Author : Arun Ponnusamy   (July 16, 2018)
# Website : http://www.arunponnusamy.com
############################################


import cv2
import argparse
import numpy as np

print("--- Python file started...")
ap = argparse.ArgumentParser()
ap.add_argument('-i', '--image', required=True,
                help = 'path to input image')
ap.add_argument('-c', '--config', required=True,
                help = 'path to yolo config file')
ap.add_argument('-w', '--weights', required=True,
                help = 'path to yolo pre-trained weights')
ap.add_argument('-cl', '--classes', required=True,
                help = 'path to text file containing class names')
args = ap.parse_args()


def get_output_layers(net):
    
    layer_names = net.getLayerNames()
    
    # Reshaping layers due to  "IndexError: invalid index to scalar variable."
    #output_layers = [layer_names[i[0] - 1] for i in net.getUnconnectedOutLayers()]
    reshaped_unconnected_layers = net.getUnconnectedOutLayers().reshape(-1, 1)
    output_layers = [layer_names[i[0] - 1] for i in reshaped_unconnected_layers]

    return output_layers


def draw_prediction(img, class_id, confidence, x, y, x_plus_w, y_plus_h):

    label = str(classes[class_id])

    color = COLORS[class_id]

    cv2.rectangle(img, (x,y), (x_plus_w,y_plus_h), color, 2)

    cv2.putText(img, label, (x-10,y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

def draw_blur(img, class_id, confidence, x, y, x_plus_w, y_plus_h):

    label = str(classes[class_id])

    color = COLORS[class_id]
    if label in ['person', 'car', 'bus', 'truck']:        
        blurval = 9
        if int(y_plus_h -y) > 100 or int(x_plus_w -x) > 100:
            blurval = 11
        if int(y_plus_h -y) > 200 or int(x_plus_w -x) > 200:
            blurval = 13
        if int(y_plus_h -y) > 300 or int(x_plus_w -x) > 300:
            blurval = 27
        
        img[int(y):int(y_plus_h), int(x):int(x_plus_w)] = cv2.medianBlur(img[int(y):int(y_plus_h), int(x):int(x_plus_w)] ,blurval)


print("Printing parsed args:")
print(args)

image = cv2.imread(args.image)

Width = image.shape[1]
Height = image.shape[0]
scale = 0.00392

classes = None

with open(args.classes, 'r') as f:
    classes = [line.strip() for line in f.readlines()]

COLORS = np.random.uniform(0, 255, size=(len(classes), 3))

net = cv2.dnn.readNet(args.weights, args.config)

blob = cv2.dnn.blobFromImage(image, scale, (416,416), (0,0,0), True, crop=False)

net.setInput(blob)

#Debugging
#print("Unconnected Out Layers: ", net.getUnconnectedOutLayers())
#print("Layer Names: ", net.getLayerNames())
#print("Type of Unconnected Out Layers: ", type(net.getUnconnectedOutLayers()))
#print("Shape of Unconnected Out Layers: ", net.getUnconnectedOutLayers().shape)


outs = net.forward(get_output_layers(net))

class_ids = []
confidences = []
boxes = []
conf_threshold = 0.5
nms_threshold = 0.4


for out in outs:
    for detection in out:
        scores = detection[5:]
        class_id = np.argmax(scores)
        confidence = scores[class_id]
        if confidence > 0.5:
            center_x = int(detection[0] * Width)
            center_y = int(detection[1] * Height)
            w = int(detection[2] * Width)
            h = int(detection[3] * Height)
            x = center_x - w / 2
            y = center_y - h / 2
            class_ids.append(class_id)
            confidences.append(float(confidence))
            boxes.append([x, y, w, h])


indices = cv2.dnn.NMSBoxes(boxes, confidences, conf_threshold, nms_threshold)

for i in indices:
    i = i[0]
    box = boxes[i]
    x = box[0]
    y = box[1]
    w = box[2]
    h = box[3]
    draw_blur(image, class_ids[i], confidences[i], round(x), round(y), round(x+w), round(y+h))
   
cv2.imwrite("/tmp/object_recognition/filtered-image.jpg", image)
cv2.destroyAllWindows()
