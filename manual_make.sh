cd ~/experiments/local_llms/llama.cpp
[ -d build ] || mkdir build
cd build
cmake .. -DLLAMA_CURL=OFF
cmake --build . --config Release
