FROM akshmakov/bossa

#socat
RUN apt-get update -y && apt-get install -y socat && rm -rf /var/lib/apt/lists/*


