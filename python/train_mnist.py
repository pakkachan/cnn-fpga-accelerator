# source ../.venv/bin/activate

# pip install torch torchvision numpy opencv-python

# maybe change up a line to make it also work on cuda if cuda is detected.. todo later

import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader


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
    

def train():
    # Convert to tensor and normalise
    transform1 = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,),(0.3081,)) # Mean and std of mnist, given 
    ])

    print(f"Downloading mnist")

    training_dataset = datasets.MNIST("./data", train=True, transform=transform1, download=True)

    # give in batches
    training_loader = DataLoader(training_dataset, batch_size = 64, shuffle = True)

    # cpu bruh i am on laptop, maybe change later, shouldnt rlly matter for speed
    device = "cpu"

    model = HardwareCNN().to(device=device) # move model to cpu

    # opt strat
    optimiser = optim.Adam(model.parameters(), lr=0.001)

    #loss
    criterion = nn.CrossEntropyLoss()

    print(f"Training on {device}")

    for epoch in range(5):
        model.train()
        total_loss = 0
        correct = 0

        for batch_idx, (data, target) in enumerate(training_loader):
            data, target = data.to(device), target.to(device)

            optimiser.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimiser.step()

            total_loss += loss.item()
            pred = output.argmax(dim = 1, keepdim = True)
            correct += pred.eq(target.view_as(pred)).sum().item()

        acc = 100. * correct/len(training_loader.dataset)
        print(f"Epoch {epoch+1}: Accuracy of {acc}%")

    torch.save(model.state_dict(), "mnist_hw_model.pth")
    print(f"Note the model is saved to 'mnist_hw_model.pth'")

if __name__ == "__main__":
    train()

"""
        # Hardware: Flatten -> Matrix Multiply

        x = x.view(-1, 16 * 13 * 13) 

        x = self.fc1(x)
"""

