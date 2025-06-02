# 🧠 Conventional Commit Message Generator
Document to help you or collaborators understand and run the model locally:

This project uses the `JosineyJr/generate-conventional-commit-messages` model to generate commit messages from `git diff`s or error logs.

---

## ⚙️ Setup

### 1. Enter the Nix Shell

```bash
nix-shell
```
The shell will create and activate a Python virtual environment automatically (in .venv/) and install dependencies:

    transformers

    torch

🚀 Usage
Option A: From a file

```bash
./generate_commit_message.sh diff.txt
```
Option B: From git diff piped directly

```bash
git diff | ./generate_commit_message.sh
```
Option C: Paste input manually

```bash
./generate_commit_message.sh
# Paste your git diff or error text, then press Ctrl+D
```
🧪 Example Output

```bash
git diff | ./generate_commit_message.sh
# => feat: add validation for user input
```
🧹 Cleanup

To remove the virtual environment:

```bash
rm -rf .venv
```
