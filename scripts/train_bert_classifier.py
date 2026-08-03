#!/usr/bin/env python3
"""
NanoAI Research — Fine-Tuning BERT/DistilBERT 110M Classifier for Real-Time Hallucination Detection

Train a 110M parameter sequence classifier on the dataset_10k.json dataset.
Can be run locally or uploaded directly to Google Colab with free T4 GPU access.

Usage:
    python scripts/train_bert_classifier.py --dataset data/research/dataset_10k.json --epochs 3 --output models/bert_hallucination_classifier
"""

import argparse
import json
import os
import sys

def check_dependencies():
    try:
        import torch
        import transformers
        return True
    except ImportError:
        print("[WARNING] PyTorch or Transformers not installed in current environment.")
        print("To run actual neural network training, install via:")
        print("    pip install torch transformers datasets scikit-learn accelerate")
        return False

def train_bert(dataset_path: str, output_dir: str, epochs: int = 3, batch_size: int = 16):
    print("=== NanoAI Research — BERT 110M Classifier Training Pipeline ===")
    print(f"Dataset path: {dataset_path}")
    print(f"Output directory: {output_dir}")
    print(f"Target Architecture: distilbert-base-uncased (110M parameters)")

    if not os.path.exists(dataset_path):
        print(f"ERROR: Dataset file not found at {dataset_path}")
        sys.exit(1)

    with open(dataset_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    print(f"Loaded {len(data)} dataset samples.")

    has_torch = check_dependencies()

    if has_torch:
        import torch
        from torch.utils.data import DataLoader, Dataset
        from transformers import AutoTokenizer, AutoModelForSequenceClassification, AdamW, get_linear_schedule_with_warmup

        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        print(f"Using PyTorch compute device: {device}")

        model_name = "distilbert-base-uncased"
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSequenceClassification.from_pretrained(model_name, num_labels=2)
        model.to(device)

        class HallucinationDataset(Dataset):
            def __init__(self, samples, tokenizer, max_len=128):
                self.texts = [s["code"] for s in samples]
                self.labels = [1 if s["has_hallucination"] else 0 for s in samples]
                self.tokenizer = tokenizer
                self.max_len = max_len

            def __len__(self):
                return len(self.texts)

            def __getitem__(self, idx):
                text = self.texts[idx]
                label = self.labels[idx]
                encoding = self.tokenizer(
                    text,
                    truncation=True,
                    max_length=self.max_len,
                    padding="max_length",
                    return_tensors="pt"
                )
                return {
                    "input_ids": encoding["input_ids"].flatten(),
                    "attention_mask": encoding["attention_mask"].flatten(),
                    "labels": torch.tensor(label, dtype=torch.long)
                }

        train_size = int(0.8 * len(data))
        train_samples = data[:train_size]
        val_samples = data[train_size:]

        train_dataset = HallucinationDataset(train_samples, tokenizer)
        val_dataset = HallucinationDataset(val_samples, tokenizer)

        train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
        optimizer = AdamW(model.parameters(), lr=2e-5)

        model.train()
        for epoch in range(epochs):
            total_loss = 0
            for step, batch in enumerate(train_loader):
                optimizer.zero_grad()
                input_ids = batch["input_ids"].to(device)
                attention_mask = batch["attention_mask"].to(device)
                labels = batch["labels"].to(device)

                outputs = model(input_ids, attention_mask=attention_mask, labels=labels)
                loss = outputs.loss
                loss.backward()
                optimizer.step()

                total_loss += loss.item()
                if step % 50 == 0:
                    print(f"Epoch {epoch+1}/{epochs} | Step {step}/{len(train_loader)} | Loss: {loss.item():.4f}")

            avg_loss = total_loss / len(train_loader)
            print(f"--> Epoch {epoch+1} Average Loss: {avg_loss:.4f}")

        os.makedirs(output_dir, exist_ok=True)
        model.save_pretrained(output_dir)
        tokenizer.save_pretrained(output_dir)
        print(f"\n✅ Model fine-tuning completed successfully! Saved to {output_dir}")

    else:
        print("\n[NOTE] PyTorch environment not detected locally.")
        print("To fine-tune the real BERT 110M model on GPU:")
        print("1. Upload data/research/dataset_10k.json to Google Colab")
        print("2. Run pip install torch transformers datasets accelerate")
        print("3. Execute this script: python scripts/train_bert_classifier.py --dataset dataset_10k.json")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", default="data/research/dataset_10k.json", help="Path to 10k JSON dataset")
    parser.add_argument("--output", default="models/bert_hallucination_classifier", help="Output model directory")
    parser.add_argument("--epochs", type=int, default=3)
    args = parser.parse_args()

    train_bert(args.dataset, args.output, args.epochs)

if __name__ == "__main__":
    main()
