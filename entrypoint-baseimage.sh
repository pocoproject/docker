#!/bin/bash

prefix=/out/$CONTAINER_NAME
OUTFILE="$prefix.out"

#rm -rf /src/poco
#rm -rf /src/openssl
rm /out/poco*

apt-get -y update >> $OUTFILE 2>&1
apt-get -y install -y git >> $OUTFILE 2>&1

# cd to external src dir
cd /src

# do git stuff
echo "poco: clone / checkout $POCO_GIT_BRANCH / pull ..." >> $OUTFILE 2>&1
if [ ! -d ./poco/.git ]; then
	git clone https://github.com/pocoproject/poco >> $OUTFILE 2>&1
else
	git pull >> $OUTFILE 2>&1
fi
cd poco >> $OUTFILE 2>&1
git checkout $POCO_GIT_BRANCH >> $OUTFILE 2>&1
git pull >> $OUTFILE 2>&1
echo "poco: clone / checkout $POCO_GIT_BRANCH / pull done." >> $OUTFILE 2>&1

# copy external configs (output of configure)
cp /config.make ./
cp /config.build ./

cd ..

LIBSSLDEV=""

if [ "$OPENSSL_GIT_BRANCH" == "" ]; then
	LIBSSLDEV=libssl-dev
fi

echo "apt-get install ..." >> $OUTFILE 2>&1
apt-get install -qq -y libpcre3-dev $LIBSSLDEV libexpat1-dev \
                       libpq-dev unixodbc-dev libmysqlclient-dev \
                       libsqlite3-dev wget make sloccount cppcheck >> $OUTFILE 2>&1
echo "apt-get install done." >> $OUTFILE 2>&1

add-apt-repository -y ppa:ubuntu-toolchain-r/test >> $OUTFILE 2>&1
apt-get update >> $OUTFILE 2>&1
if [ "$CC" == "gcc" ]; then
	echo "gcc: installing ${CC}-${POCO_COMPILER_VERSION} ${CXX}-${POCO_COMPILER_VERSION}" >> $OUTFILE 2>&1
	apt-get install -y ${CC}-${POCO_COMPILER_VERSION} ${CXX}-${POCO_COMPILER_VERSION} >> $OUTFILE 2>&1
	update-alternatives --install /usr/bin/${CC} ${CC} /usr/bin/${CC}-${POCO_COMPILER_VERSION} 60 \
						--slave /usr/bin/${CXX} ${CXX} /usr/bin/${CXX}-${POCO_COMPILER_VERSION} >> $OUTFILE 2>&1
	echo "gcc install done" >> $OUTFILE 2>&1
elif [ "$CC" == "clang" ]; then
	echo "clang: installing ${CC}-${POCO_COMPILER_VERSION} ${CXX}-${POCO_COMPILER_VERSION}" >> $OUTFILE 2>&1
	if [ -z `grep "http://llvm.org/apt/" /etc/apt/sources.list` ]; then
		bash -c "cat >> /etc/apt/sources.list" < build/script/clang.apt
	fi
	wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key|apt-key add - >> $OUTFILE 2>&1
	apt-get update  -qq >> $OUTFILE 2>&1
	apt-get install -qq -y ${CC}-${POCO_COMPILER_VERSION} lldb-${POCO_COMPILER_VERSION} libc++-dev libc++abi-dev >> $OUTFILE 2>&1
	echo "clang install done" >> $OUTFILE 2>&1
fi

export CC="${CC}-${POCO_COMPILER_VERSION}"
export CXX="${CXX}-${POCO_COMPILER_VERSION}"

if [ "$OPENSSL_GIT_BRANCH" != "" ]; then
	apt-get remove -qq -y libssl-dev >> $OUTFILE 2>&1
	if [ ! -d ./openssl/.git ]; then
		git clone https://github.com/openssl/openssl >> $OUTFILE 2>&1
	else
		git pull >> $OUTFILE 2>&1
	fi
	cd openssl
	echo "openssl: checking out $OPENSSL_GIT_BRANCH" >> $OUTFILE 2>&1
	git checkout $OPENSSL_GIT_BRANCH >> $OUTFILE 2>&1
	git pull
	echo "openssl: building $OPENSSL_GIT_BRANCH" >> $OUTFILE 2>&1
	./Configure && make && make install >> $OUTFILE 2>&1
	cd /usr/lib
	ln -s /usr/local/lib64 openssl
	cd /usr/include/
	ln -s /usr/local/include/openssl/ openssl
	echo "openssl: build $OPENSSL_GIT_BRANCH done." >> $OUTFILE 2>&1
fi

$CXX --version >> $OUTFILE 2>&1

echo "poco: build $POCO_GIT_BRANCH ..." >> $OUTFILE 2>&1
cd /src/poco
export HOME="/root"
export POCO_BASE=`pwd`

cd CppUnit
make -s -j4 >> $OUTFILE 2>&1

cd ../Foundation
make -s -j4 >> $OUTFILE 2>&1

cd ../Crypto
make -s -j4 >> $OUTFILE 2>&1
cd testsuite
make -s -j4 >> $OUTFILE 2>&1

cd ../../JSON
make -s -j4 >> $OUTFILE 2>&1

cd ../XML
make -s -j4 >> $OUTFILE 2>&1

cd ../Util
make -s -j4 >> $OUTFILE 2>&1

cd ../Net
make -s -j4 >> $OUTFILE 2>&1

cd ../NetSSL_OpenSSL
make -s -j4 >> $OUTFILE 2>&1
cd testsuite
make -s -j4 >> $OUTFILE 2>&1
cd ../..
echo "poco: build $POCO_GIT_BRANCH done." >> $OUTFILE 2>&1

export LD_LIBRARY_PATH=/src/poco/lib/Linux/x86_64:/usr/lib/openssl
Crypto/testsuite/bin/Linux/x86_64/testrunner -all >> $OUTFILE 2>&1
NetSSL_OpenSSL/testsuite/bin/Linux/x86_64/testrunner -all >> $OUTFILE 2>&1

function spin {
    echo "Idle script (to keep container up) running."

    cleanup ()
    {
        kill -s SIGTERM $!
        exit 0
    }

    trap cleanup SIGINT SIGTERM

    while [ 1 ]
    do
        sleep 60 &
        wait $!
    done
}

# keeps container running after build/test work is done
# (convenient to `exec -it [ID] bash` into running
#  container and try some things manually)
# if commented the container dies after work is done
# (can be started again with `run start`)

#spin
