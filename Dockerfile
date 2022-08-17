FROM debian:bullseye-slim
ARG LLVM_VERSION=14
RUN apt-get update -yq \
 && apt-get install --yes --no-install-recommends \
    ca-certificates \
    cmake \
    git \
    gnupg \
    libbz2-dev \
    libgfortran5 \
    libgfortran-10-dev \
    lsb-release \
    make \
    ninja-build \
    software-properties-common \
    unzip \
    wget \
    zlib1g \
 && rm -rf /var/lib/apt/lists/* \
 && wget https://apt.llvm.org/llvm.sh \
 && chmod +x llvm.sh \
 && ./llvm.sh ${LLVM_VERSION} all \
 && ln /usr/bin/clang-${LLVM_VERSION} /usr/bin/clang \
 && ln /usr/bin/clang-${LLVM_VERSION} /usr/bin/clang++ \
 && clang --version \
 && clang++ --version

# BOOST 1.60 with Boost geometry extensions
# SSC : system thread random chrono
# XDYN : program_options filesystem system regex
# libbz2 is required for Boost compilation
RUN wget --quiet https://boostorg.jfrog.io/artifactory/main/release/1.79.0/source/boost_1_79_0.tar.gz -O boost_src.tar.gz \
 && mkdir -p boost_src \
 && tar -xzf boost_src.tar.gz --strip 1 -C boost_src \
 && rm -rf boost_src.tar.gz \
 && cd boost_src \
 && ./bootstrap.sh --with-toolset=clang \
 && ./b2 toolset=clang cxxflags="-stdlib=libc++" linkflags="-stdlib=libc++" \
    cxxflags=-fPIC \
    --without-mpi \
    --without-python \
    link=static \
    threading=single \
    threading=multi \
    --layout=tagged \
    --prefix=/opt/boost \
    install \
 && cd .. \
 && rm -rf boost_src

# BOOST Geometry extension, needed for ssc. Version for boost 1.79
RUN git clone https://github.com/boostorg/geometry \
 && cd geometry \
 && git checkout 49004c5dddb49c10be101e6727d94f11fecead87 \
 && cp -rf include/boost/geometry/extensions /opt/boost/include/boost/geometry/. \
 && cd .. \
 && rm -rf geometry

RUN wget --quiet https://github.com/eigenteam/eigen-git-mirror/archive/3.3.5.tar.gz -O eigen.tgz \
 && mkdir -p /opt/eigen \
 && tar -xzf eigen.tgz --strip 1 -C /opt/eigen \
 && rm -rf eigen.tgz

RUN wget --quiet https://github.com/jbeder/yaml-cpp/archive/release-0.3.0.tar.gz -O yaml_cpp.tgz \
 && mkdir -p /opt/yaml_cpp \
 && tar -xzf yaml_cpp.tgz --strip 1 -C /opt/yaml_cpp \
 && rm -rf yaml_cpp.tgz

RUN wget --quiet https://github.com/google/googletest/archive/release-1.12.1.tar.gz -O googletest.tgz \
 && mkdir -p /opt/googletest \
 && tar -xzf googletest.tgz --strip 1 -C /opt/googletest \
 && rm -rf googletest.tgz

RUN wget --quiet https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz -O websocketpp.tgz \
 && mkdir -p /opt/websocketpp \
 && tar -xzf websocketpp.tgz --strip 1 -C /opt/websocketpp \
 && rm -rf websocketpp.tgz

RUN mkdir -p /opt/libf2c \
 && cd /opt/libf2c \
 && wget --quiet http://www.netlib.org/f2c/libf2c.zip -O libf2c.zip \
 && unzip libf2c.zip \
 && rm -rf libf2c.zip

RUN wget --quiet https://sourceforge.net/projects/geographiclib/files/distrib/archive/GeographicLib-1.30.tar.gz/download -O geographiclib.tgz \
 && mkdir -p /opt/geographiclib \
 && tar -xzf geographiclib.tgz --strip 1 -C /opt/geographiclib \
 && rm -rf geographiclib.tgz

ENV HDF5_INSTALL=/usr/local/hdf5
RUN wget --quiet https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.12/src/hdf5-1.8.12.tar.gz -O hdf5_source.tar.gz \
 && mkdir -p HDF5_SRC \
 && tar -xf hdf5_source.tar.gz --strip 1 -C HDF5_SRC \
 && mkdir -p HDF5_build \
 && cd HDF5_build \
 && cmake \
      -G "Unix Makefiles" \
      -D CMAKE_CXX_COMPILER=clang++ \
      -D CMAKE_C_COMPILER=clang \
      -D CMAKE_BUILD_TYPE:STRING=Release \
      -D CMAKE_INSTALL_PREFIX:PATH=${HDF5_INSTALL} \
      -D BUILD_SHARED_LIBS:BOOL=OFF \
      -D BUILD_TESTING:BOOL=OFF \
      -D HDF5_BUILD_TOOLS:BOOL=OFF \
      -D HDF5_BUILD_EXAMPLES:BOOL=OFF \
      -D HDF5_BUILD_HL_LIB:BOOL=ON \
      -D HDF5_BUILD_CPP_LIB:BOOL=ON \
      -D HDF5_BUILD_FORTRAN:BOOL=OFF \
      -D CMAKE_C_FLAGS="-fPIC" \
      -D CMAKE_CXX_FLAGS="-fPIC" \
      ../HDF5_SRC \
 && make install \
 && cd .. \
 && rm -rf hdf5_source.tar.gz HDF5_SRC HDF5_build

RUN cd /opt \
 && git clone https://github.com/garrison/eigen3-hdf5 \
 && cd eigen3-hdf5 \
 && git checkout 2c782414251e75a2de9b0441c349f5f18fe929a2

ARG GIT_GRPC_TAG=v1.46.3
RUN git clone --recurse-submodules -b ${GIT_GRPC_TAG} https://github.com/grpc/grpc grpc_src \
 && cd grpc_src \
 && mkdir -p cmake/build \
 && cd cmake/build \
 && cmake \
      -G "Unix Makefiles" \
      -D CMAKE_CXX_COMPILER=clang++ \
      -D CMAKE_C_COMPILER=clang \
      -D gRPC_INSTALL:BOOL=ON \
      -D CMAKE_INSTALL_PREFIX=/opt/grpc \
      -D CMAKE_BUILD_TYPE=Release \
      -D gRPC_BUILD_TESTS:BOOL=OFF \
      -D BUILD_SHARED_LIBS:BOOL=OFF \
      -D CMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON \
      -D CMAKE_C_FLAGS="-fPIC" \
      -D CMAKE_CXX_FLAGS="-fPIC" \
      -D CMAKE_VERBOSE_MAKEFILE:BOOL=OFF \
      ../.. \
 && make install \
 && cd ../../.. \
 && rm -rf grpc_src
 
