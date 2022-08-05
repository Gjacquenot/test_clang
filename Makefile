all: update-submodules debian-clang

DOCKER_AS_ROOT:=docker run -t --rm -w /opt/share -v $(shell pwd)/xdyn:/opt/share
DOCKER_AS_USER:=$(DOCKER_AS_ROOT) -u $(shell id -u):$(shell id -g)

MAKE:=make \
BUILD_TYPE=Release \
BUILD_DIR=build_clang \
CPACK_GENERATOR=DEB \
DOCKER_IMAGE=gjacquenot/xdynclang \
BOOST_ROOT=/opt/boost_1_63_0 \
HDF5_DIR=/usr/local/hdf5/share/cmake \
BUILD_PYTHON_WRAPPER=False

debian-clang: headers clang_release

headers:
	${MAKE} -C xdyn headers

update-submodules:
	@echo "Updating Git submodules..."
	@git submodule sync --recursive
	@git submodule update --init --recursive
	@git submodule foreach --recursive 'git fetch --tags'

clang_release: BUILD_TYPE = Release
clang_release: BUILD_DIR = build_clang
clang_release: CPACK_GENERATOR = DEB
clang_release: DOCKER_IMAGE = gjacquenot/xdynclang
clang_release: BOOST_ROOT = /opt/boost_1_63_0
clang_release: HDF5_DIR = /usr/local/hdf5/share/cmake
clang_release: BUILD_PYTHON_WRAPPER = False
clang_release: cmake-debian-clang-target build-debian-clang test-debian-clang

xdyn/code/yaml-cpp/CMakeLists.txt:
	${MAKE} -C xdyn code/yaml-cpp/CMakeLists.txt

cmake-debian-clang-target: SHELL:=/bin/bash
cmake-debian-clang-target: xdyn/code/yaml-cpp/CMakeLists.txt
	docker pull $(DOCKER_IMAGE) || true
	$(DOCKER_AS_USER) $(DOCKER_IMAGE) /bin/bash -c \
	   "cd /opt/share &&\
	    mkdir -p $(BUILD_DIR) &&\
	    cd $(BUILD_DIR) &&\
	    cmake -Wno-dev \
	     -G Ninja \
	     -D CMAKE_CXX_COMPILER=clang++ \
	     -D CMAKE_C_COMPILER=clang \
	     -D THIRD_PARTY_DIRECTORY=/opt/ \
	     -D BUILD_DOCUMENTATION:BOOL=False \
	     -D CPACK_GENERATOR=$(CPACK_GENERATOR) \
	     -D CMAKE_BUILD_TYPE=$(BUILD_TYPE) \
	     -D CMAKE_INSTALL_PREFIX:PATH=/opt/xdyn \
	     -D HDF5_DIR=$(HDF5_DIR) \
	     -D BOOST_ROOT:PATH=$(BOOST_ROOT) \
	     -D BUILD_PYTHON_WRAPPER:BOOL=$(BUILD_PYTHON_WRAPPER) \
	     $(ADDITIONAL_CMAKE_PARAMETERS) \
	    /opt/share/code"

build-debian-clang: SHELL:=/bin/bash
build-debian-clang:
	$(DOCKER_AS_USER) $(DOCKER_IMAGE) /bin/bash -c \
	   "cd /opt/share && \
	    mkdir -p $(BUILD_DIR) && \
	    cd $(BUILD_DIR) && \
	    ninja $(NB_OF_PARALLEL_BUILDS) package"

test-debian-clang: SHELL:=/bin/bash
test-debian-clang:
	$(DOCKER_AS_USER) $(DOCKER_IMAGE) /bin/bash -c \
	   "cp validation/codecov_bash.sh $(BUILD_DIR) && \
	    cd $(BUILD_DIR) &&\
	    ./run_all_tests &&\
	    if [[ $(BUILD_TYPE) == Coverage ]];\
	    then\
	    echo Coverage;\
	    gprof run_all_tests gmon.out > gprof_res.txt 2> gprof_res.err;\
	    bash codecov_bash.sh && \
	    rm codecov_bash.sh;\
	    fi"

xdyn.deb: build_deb11/xdyn.deb
	@cp $< $@

build_deb11/xdyn.deb:
	@echo "Run ./ninja_debian.sh package"

clean:
	rm -f xdyn.deb
	rm -rf build_*
	rm -rf yaml-cpp
	@${MAKE} -C doc_user clean; rm -f doc_user/xdyn.deb doc.html
	@${MAKE} -C code/wrapper_python clean
