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

ENTRYPOINT ["sleep", "1000000000000000000"]

# Download and compile gmp for CGAL
RUN wget https://ftp.gnu.org/gnu/gmp/gmp-6.1.1.tar.bz2 && \
  bzip2 -dc gmp-6.1.1.tar.bz2 | tar xvf - && \
  cd gmp-6.1.1 && \
  ./configure && \
  make && \
  make check && \
  make install && \
  rm -rf gmp-6.1.1 gmp-6.1.1.tar.bz2

# Download and compile mpfr for CGAL
RUN wget http://www.mpfr.org/mpfr-current/mpfr-3.1.5.tar.bz2 && \
  bzip2 -dc mpfr-3.1.5.tar.bz2 | tar xvf - && \
  cd mpfr-3.1.5 && \
  ./configure --with-gmp-build=/root/gmp-6.1.1 && \
  make && \
  make check && \
  make install && \
  rm -rf mpfr-3.1.5 mpfr-3.1.5.tar.bz2

# Download and compile Boost for CMake
RUN wget http://sourceforge.net/projects/boost/files/boost/1.58.0/boost_1_58_0.tar.bz2 && \
  bzip2 -dc boost_1_58_0.tar.bz2 | tar xvf - && \
  cd boost_1_58_0 && \
  ./bootstrap.sh && \
  ./b2 && \
  rm -rf boost_1_58_0 boost_1_58_0.tar.bz2

# # Download and compile CGAL
# RUN wget https://gforge.inria.fr/frs/download.php/file/32994/CGAL-4.3.tar.gz && \
#   tar -xzf CGAL-4.3.tar.gz && \
#   cd CGAL-4.3 && \
#   mkdir build && \
#   cd build && \
#   cmake .. && \
#   make -j3 && \
#   make install && \

# # download and compile SFCGAL
# RUN git clone https://github.com/Oslandia/SFCGAL.git && \
#   cd SFCGAL && \
#   cmake . && \
#   make -j3 && make install && \
#   rm -Rf SFCGAL

# # download and install GEOS 3.5
# RUN wget http://download.osgeo.org/geos/geos-3.5.0.tar.bz2 && \
#   tar -xjf geos-3.5.0.tar.bz2 && \
#   cd geos-3.5.0 && \
#   ./configure && make && make install && \
#   cd .. && rm -Rf geos-3.5.0 geos-3.5.0.tar.bz2

# # Download and compile PostGIS
# RUN wget http://download.osgeo.org/postgis/source/postgis-2.2.0.tar.gz
# RUN tar -xzf postgis-2.2.0.tar.gz
# RUN cd postgis-2.2.0 && ./configure --with-sfcgal=/usr/local/bin/sfcgal-config --with-geos=/usr/local/bin/geos-config
# RUN cd postgis-2.2.0 && make && make install
# # cleanup
# RUN rm -Rf postgis-2.2.0.tar.gz postgis-2.2.0

# # Download and compile pgrouting
# RUN git clone https://github.com/pgRouting/pgrouting.git && \
#     cd pgrouting && \
#     mkdir build && cd build && \
#     cmake -DWITH_DOC=OFF -DWITH_DD=ON .. && \
#     make -j3 && make install
# # cleanup
# RUN rm -Rf pgrouting

# # Download and compile ogr_fdw
# RUN git clone https://github.com/pramsey/pgsql-ogr-fdw.git && \
#     cd pgsql-ogr-fdw && \
#     make && make install && \
#     cd .. && rm -Rf pgsql-ogr-fdw

# # Compile PDAL
# RUN git clone https://github.com/PDAL/PDAL.git pdal
# RUN mkdir PDAL-build && \
#     cd PDAL-build && \
#     cmake ../pdal && \
#     make -j3 && \
#     make install
# # cleanup
# RUN rm -Rf pdal && rm -Rf PDAL-build

# # Compile PointCloud
# RUN git clone https://github.com/pramsey/pointcloud.git
# RUN cd pointcloud && ./autogen.sh && ./configure && make -j3 && make install
# # cleanup
# RUN rm -Rf pointcloud

# # get compiled libraries recognized
# RUN ldconfig

# # add a baseimage PostgreSQL init script
# RUN mkdir /etc/service/postgresql
# ADD postgresql.sh /etc/service/postgresql/run

# # Adjust PostgreSQL configuration so that remote connections to the
# # database are possible.
# RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.5/main/pg_hba.conf

# # And add ``listen_addresses`` to ``/etc/postgresql/9.5/main/postgresql.conf``
# RUN echo "listen_addresses='*'" >> /etc/postgresql/9.5/main/postgresql.conf

# # Expose PostgreSQL
# EXPOSE 5432

# # Add VOLUMEs to allow backup of config, logs and databases
# VOLUME  ["/data", "/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

# # add database setup upon image start
# ADD pgpass /root/.pgpass
# RUN chmod 700 /root/.pgpass
# RUN mkdir -p /etc/my_init.d
# ADD init_db_script.sh /etc/my_init.d/init_db_script.sh
# ADD init_db.sh /root/init_db.sh

# # Compile TinyOWS
# RUN git clone https://github.com/mapserver/tinyows.git
# RUN cd tinyows && autoconf && ./configure --with-shp2pgsql=/usr/lib/postgresql/9.5/bin/shp2pgsql && make && make install && cp tinyows /usr/lib/cgi-bin/tinyows
# # cleanup
# RUN rm -Rf tinyows

# # get compiled libraries recognized
# RUN ldconfig

# # Add TinyOWS configuration
# ADD tinyows.xml /etc/tinyows.xml

