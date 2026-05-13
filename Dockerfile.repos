FROM alpine:3.19

# Instalar git
RUN apk add --no-cache git

# Crear la carpeta principal del proyecto
WORKDIR /tesis

# Crear subcarpetas
RUN mkdir -p Server Client Spring Angular Python

# Clonar los repos en sus carpetas
RUN git clone https://github.com/ng-g-c-Nathan/AngularInterfaceForOpenVPN Angular/AngularInterfaceForOpenVPN && \
    git clone https://github.com/ng-g-c-Nathan/SpringBoot-with-OpenVPN Spring/SpringBoot-with-OpenVPN && \
    git clone https://github.com/ng-g-c-Nathan/network-anomaly-scoring Python/network-anomaly-scoring

# Mostrar la estructura al correr el contenedor
CMD ["sh", "-c", "echo 'Estructura lista:' && find /tesis -maxdepth 2 -type d | sort"]
