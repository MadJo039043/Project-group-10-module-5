from torchvision import datasets, transforms

#Download MNIST to 'root' directory
#If the directory does not exist, it will be created
mnist = datasets.MNIST(
    root='./mnist_data/',      
    train=True,
    download=True,
)