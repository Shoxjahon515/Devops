import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)
VERSION = os.getenv("APP_VERSION", "1.0.0")


@app.get("/")
def index():
    return jsonify(service="payfast-hello", version=VERSION, host=socket.gethostname())


@app.get("/health")
def health():
    return jsonify(status="ok")
