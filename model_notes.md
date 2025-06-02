The Hugging Face repository [JosineyJr/generate-conventional-commit-messages](https://huggingface.co/JosineyJr/generate-conventional-commit-messages/tree/main) hosts a fine-tuned model designed to automate the generation of conventional commit messages. This model, known as CommitWizard, leverages pre-trained language models to produce commit messages that adhere to standardized formats, enhancing clarity and consistency in version control practices.([Hugging Face][1], [arXiv][2])

### 🔧 Model Overview

* **Base Model**: The model is built upon Meta's LLaMA 2 8B model.
* **Fine-Tuning**: It has been fine-tuned using the Unsloth dataset, which is tailored for code-related tasks.
* **Quantization**: The model employs 4-bit quantization to optimize memory usage while maintaining efficiency and accuracy.
* **License**: Released under the Apache-2.0 license.([Hugging Face][1], [Hugging Face][3])

### 📁 Repository Contents

The repository includes:

* `adapter_model.safetensors`: The fine-tuned model weights.
* `adapter_config.json`: Configuration file for the model.
* `.gitattributes`: Git attributes file.
* `README.md`: Documentation for the model.([Hugging Face][3])

### 🚀 Usage

To utilize this model, you can load it using the Hugging Face `transformers` library. Here's a basic example:

```python
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

tokenizer = AutoTokenizer.from_pretrained("JosineyJr/generate-conventional-commit-messages")
model = AutoModelForSeq2SeqLM.from_pretrained("JosineyJr/generate-conventional-commit-messages")

inputs = tokenizer("Refactor user authentication module", return_tensors="pt")
outputs = model.generate(**inputs)
commit_message = tokenizer.decode(outputs[0], skip_special_tokens=True)

print(commit_message)
```



This script will generate a commit message based on the provided input.

For more details and to access the model, visit the [repository page](https://huggingface.co/JosineyJr/generate-conventional-commit-messages/tree/main).

[1]: https://huggingface.co/JosineyJr/generate-conventional-commit-messages?utm_source=chatgpt.com "JosineyJr/generate-conventional-commit-messages - Hugging Face"
[2]: https://arxiv.org/abs/2105.14242?utm_source=chatgpt.com "CommitBERT: Commit Message Generation Using Pre-Trained Programming Language Model"
[3]: https://huggingface.co/JosineyJr/generate-conventional-commit-messages/tree/54927c7a09a0bd301d65d8dfd312603b91d4bea8?utm_source=chatgpt.com "JosineyJr/generate-conventional-commit-messages ... - Hugging Face"
