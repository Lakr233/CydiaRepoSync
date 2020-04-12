#!/bin/bash

git submodule init
git submodule update

tar -cvf ./submoduleCache.tar ./SWCompression ./BitByteData
