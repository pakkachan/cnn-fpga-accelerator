import cv2
import torch
import torch.nn as nn
import numpy as np

class HardwareCNN(nn.Module):
    def __init__(self):
        super().__init__()

        self.conv1 = nn.Conv2d(in_channels=1, out_channels=16, kernel_size=3, stride=1, padding=0)
        self.pool = nn.MaxPool2d(kernel_size=2, stride=2)
        self.fc1 = nn.Linear(16 * 13 * 13, 10) # 10 output classes (0 - 9 detection)

    def forward(self, x):
        x = self.conv1(x)
        x = torch.relu(x)
        x = self.pool(x)

        x = x.view(-1, 16 * 13 * 13)
        x = self.fc1(x)
        return x
    

device = "cpu"
model = HardwareCNN().to(device=device)
model_path = "../mnist_hw_model.pth" # change prolly later
model.load_state_dict(torch.load(model_path))
model.eval()

#ui state
drawing = False
canvas = np.zeros((280, 280), dtype=np.uint8)



def process_and_predict(img):
    # 1.) resize the img down to 28x28
    img_resized = cv2.resize(img, (28,28), interpolation=cv2.INTER_AREA) #area interpolation

    # 2.) normalise values to [0, 1) and apply 
    img_input = torch.from_numpy(img_resized).float() / 255.0
    img_input = (img_input - 0.1307) / 0.3081 # (x-mu)/sd
    img_input = img_input.unsqueeze(0).unsqueeze(0) # goes from (28,28) to (1,1,28,28) since nn.Conv2d expects a 4D tensor

    # run the processed image through the CNN
    with torch.no_grad():
        output = model(img_input) # tensor of 10 numbers
        prediction = output.argmax(dim = 1).item() # return index of highest output score
        confidence_level = torch.nn.functional.softmax(output, dim=1).max().item() # gives conf level
        print(f"Prediction: {prediction}, Confidence level: {confidence_level:.3f}")


def mouse_event(event, x, y, flags, param):
    global drawing, canvas
    if event == cv2.EVENT_LBUTTONDOWN:
        drawing = True
    elif event == cv2.EVENT_MOUSEMOVE:
        if drawing:
            cv2.circle(canvas, (x,y), 5, (255), -1)
    elif event == cv2.EVENT_LBUTTONUP:
        drawing = False
        process_and_predict(canvas)

if __name__ == "__main__":
    cv2.namedWindow("Draw a digit from 0 - 9, (c to clear, q to quit)")
    cv2.setMouseCallback("Draw a digit from 0 - 9, (c to clear, q to quit)", mouse_event)

    while True:
        cv2.imshow("Draw a digit from 0 - 9, (c to clear, q to quit)", canvas)
        key = cv2.waitKey(1) & 0xFF
        if key == ord("c"):
            canvas[:] = 0
        elif key == ord("q"):
            break

    cv2.destroyAllWindows()



