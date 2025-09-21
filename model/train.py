import os
import argparse
import zipfile
from ultralytics import YOLO

def main(args):
    # 1. Unzip dataset in a robust way
    print("Unzipping dataset...")
    zip_path = '/opt/ml/input/data/train/FinalDataset1.zip'
    extract_path = '/opt/ml/input/data/train/'
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_path)
    print("Dataset unzipped successfully.")

    # 2. Define path to your data.yaml
    data_yaml_path = "/opt/ml/input/data/train/Main/data.yaml"

    # 3. Load the checkpoint model
    model = YOLO("/opt/ml/input/data/checkpoints/last.pt")

    # 4. Resume training using hyperparameters
    print(f"Resuming training for {args.epochs} epochs...")
    model.train(
        data=data_yaml_path,
        epochs=args.epochs,
        imgsz=args.imgsz,
        patience=args.patience,
        resume=True  # This is crucial for resuming
    )
    print("Training finished.")

    # 5. Save the final model to the required SageMaker directory
    # Ultralytics saves runs to a 'runs' directory in the current working dir
    output_path = "runs/detect/train/weights/best.pt"
    if os.path.exists(output_path):
        os.system(f"cp {output_path} /opt/ml/model/")
        print("Model 'best.pt' saved to /opt/ml/model/")
    else:
        print("Training did not produce a 'best.pt' model.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    # Hyperparameters sent by SageMaker
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--patience", type=int, default=10)
    parser.add_argument("--imgsz", type=int, default=640)

    args = parser.parse_args()
    main(args)