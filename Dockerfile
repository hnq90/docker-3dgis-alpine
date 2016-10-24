# PostgreSQL GIS stack
#
# This image includes the following tools
# - PostgreSQL 9.5
# - PostGIS 2.2 with raster, topology and sfcgal support
# - OGR Foreign Data Wrapper
# - PgRouting
# - PDAL master
# - PostgreSQL PointCloud version master

FROM onjin/alpine-postgres:9.5

MAINTAINER Huy Nguyen Quang <huy@huynq.net>

# Set correct environment variables.
ENV HOME /root

RUN echo "@testing http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
  apk add --update --no-cache autoconf build-base alpine-sdk boost boost-dev gmp cmake libgcc git wget ca-certificates tar xz bzip2

# Download and install glibc
# Replace this public key by yours
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub && \
  wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.23-r3/glibc-2.23-r3.apk && \
  apk add glibc-2.23-r3.apk

# Download and compile gmp for CGAL
RUN cd /root && \
  wget https://ftp.gnu.org/gnu/gmp/gmp-6.1.1.tar.bz2 && \
  bzip2 -dc gmp-6.1.1.tar.bz2 | tar xvf - && \
  cd gmp-6.1.1 && \
  ./configure && \
  make && \
  make check && \
  make install

# Download and compile mpfr for CGAL
RUN cd /root && \
  wget http://www.mpfr.org/mpfr-current/mpfr-3.1.5.tar.bz2 && \
  bzip2 -dc mpfr-3.1.5.tar.bz2 | tar xvf - && \
  cd mpfr-3.1.5 && \
  ./configure --with-gmp-build=/root/gmp-6.1.1 && \
  make && \
  make check && \
  make install

ENTRYPOINT ["sleep", "1000000000000000000"]

# Download and compile CGAL
RUN cd /root && \
  wget https://github.com/CGAL/cgal/releases/download/releases%2FCGAL-4.9/CGAL-4.9.tar.xz && \
  xz -df CGAL-4.9.tar.xz && \
  tar -xvf CGAL-4.9.tar && \
  cd CGAL-4.9 && \
  mkdir build && \
  cd build && \
  cmake .. && \
  make -j3 && \
  make install

# Download and compile SFCGAL
RUN cd /root && \
  git clone https://github.com/Oslandia/SFCGAL.git && \
  cd SFCGAL && \
  cmake . && \
  make -j3 && \
  make install

# Download and install GEOS 3.5
RUN cd /root && \
  wget http://download.osgeo.org/geos/geos-3.5.0.tar.bz2 && \
  tar -xjf geos-3.5.0.tar.bz2 && \
  cd geos-3.5.0 && \
  ./configure && \
  make && make install

# Download and compile PostGIS
RUN cd /root && \
  wget http://download.osgeo.org/postgis/source/postgis-2.2.0.tar.gz && \
  tar -xzf postgis-2.2.0.tar.gz && \
  cd postgis-2.2.0 && \
  ./configure --with-sfcgal=/usr/local/bin/sfcgal-config --with-geos=/usr/local/bin/geos-config && \
  cd postgis-2.2.0 && \
  make && \
  make install

# Download and compile pgrouting
RUN cd /root && \
  git clone https://github.com/pgRouting/pgrouting.git && \
  cd pgrouting && \
  mkdir build && \
  cd build && \
  cmake -DWITH_DOC=OFF -DWITH_DD=ON .. && \
  make -j3 && \
  make install

# Download and compile ogr_fdw
RUN cd /root && \
  git clone https://github.com/pramsey/pgsql-ogr-fdw.git && \
  cd pgsql-ogr-fdw && \
  make && \
  make install

# Download and compile PDAL
RUN cd /root && \
  git clone https://github.com/PDAL/PDAL.git pdal && \
  mkdir PDAL-build && \
  cd PDAL-build && \
  cmake ../pdal && \
  make -j3 && \
  make install

# Download and compile PointCloud
RUN cd /root && \
  git clone https://github.com/pramsey/pointcloud.git && \
  cd pointcloud && \
  ./autogen.sh && \
  ./configure && \
  make -j3 && \
  make install

# Get compiled libraries recognized
RUN ldconfig

# Add a baseimage PostgreSQL init script
RUN mkdir /etc/service/postgresql
ADD postgresql.sh /etc/service/postgresql/run

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.5/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/9.5/main/postgresql.conf``
RUN echo "listen_addresses='*'" >> /etc/postgresql/9.5/main/postgresql.conf

# Add VOLUMEs to allow backup of config, logs and databases
VOLUME  ["/data", "/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

# Add database setup upon image start
ADD pgpass /root/.pgpass
RUN chmod 700 /root/.pgpass && \
  mkdir -p /etc/my_init.d
ADD init_db_script.sh /etc/my_init.d/init_db_script.sh
ADD init_db.sh /root/init_db.sh

# Download and compile TinyOWS
RUN cd /root && \
  git clone https://github.com/mapserver/tinyows.git && \
  cd tinyows && \
  autoconf && \
  ./configure --with-shp2pgsql=/usr/lib/postgresql/9.5/bin/shp2pgsql && \
  make && \
  make install && \
  cp tinyows /usr/lib/cgi-bin/tinyows

# get compiled libraries recognized
RUN ldconfig

# Add TinyOWS configuration
ADD tinyows.xml /etc/tinyows.xml

# Clean
RUN cd /root && \
  rm -rf mpfr-3.1.5 mpfr-3.1.5.tar.bz2 \
  gmp-6.1.1 gmp-6.1.1.tar.bz2 \
  CGAL-4.9 CGAL-4.9.tar \
  SFCGAL \
  geos-3.5.0 geos-3.5.0.tar.bz2 \
  postgis-2.2.0.tar.gz postgis-2.2.0 \
  pgrouting \
  pgsql-ogr-fdw \
  pdal PDAL-build \
  pointcloud \
  tinyows

# Expose PostgreSQL
EXPOSE 5432
