Great questions! Let's break down what you ran and why RAM use might not have increased:

---

### 1. **What model did you run?**

From the output, the model you loaded is:

```
/home/dmei/experiments/local_llms/merged-model/merged_model.gguf
```

**Details from metadata:**

* Model name: `Merged Model`
* Size: `8.0B` parameters (approx. 8 billion)
* Format: GGUF V3 (latest)
* Quantization: Q8\_0 (8-bit quantization)
* Context length: 8192 tokens
* 32 layers, 32 attention heads
* Uses llama architecture

---

### 2. **Why didn't RAM use go up?**

* **8-bit quantization (Q8\_0):**
  The model is quantized to 8-bit, which drastically reduces memory usage compared to 16-bit or 32-bit floating-point weights. This means the RAM footprint is much smaller, which is why you might not see a huge spike in RAM usage.

* **Model loading strategy:**
  `llama.cpp` and its derivatives often use **memory mapping** (`mmap`) for loading models. This means the model file on disk is mapped into virtual memory but not fully loaded into RAM upfront — parts are paged in as needed. So, actual RAM usage might appear low until active inference operations require parts of the model.

* **OS caching and reporting:**
  Sometimes Linux memory reporting tools (e.g., `top`, `htop`) show less RAM used because a lot of memory is in shared or cached segments.

---

### 3. **Can you increase performance by allowing it to use more RAM?**

Yes! Some tips:

* **Disable swap or mmap, force loading into RAM:**
  Some inference programs have options to load the entire model into RAM instead of memory-mapping it. This can reduce I/O latency during inference.

* **Use higher precision:**
  Using float16 or float32 weights increases RAM use but may improve accuracy and inference speed depending on your CPU/GPU.

* **Increase context length:**
  Larger context window uses more RAM but allows the model to process longer inputs at once.

* **Batch inference:**
  Processing multiple prompts in parallel can use more RAM but improve throughput.

* **Enable multithreading:**
  Check if `llama-cli` or your runner has options to control number of threads, affinity, or SIMD optimizations.

---

### 4. **How to confirm RAM usage?**

Run `htop` or `free -h` while inference is running. Look for:

* Resident Set Size (RSS) of the process
* Shared vs private memory
* Cached memory from mmap-ed files

---

### 5. **How to tweak your build or run for better RAM and performance?**

You can:

* Pass flags like `--use-mmap=false` if supported by your runner to load the whole model in RAM.
* Experiment with environment variables controlling memory (e.g., for llama.cpp there’s `GGML_USE_MMAP`).
* Check for command-line options to specify precision, threading, or memory management.

---

### Summary

You built and ran an 8B-parameter, 8-bit quantized llama model (`merged_model.gguf`) with `llama-cli`.
Its low RAM usage is expected due to 8-bit quantization and memory mapping.
You can increase RAM usage/performance by disabling mmap, increasing precision, or batching.

---

If you want, I can help you:

* Identify specific runtime flags to change memory usage
* Suggest commands to monitor RAM during inference
* Help with building a higher-precision or non-mmap version of the model

---

Would you like to see some example commands or config options to tweak this?
