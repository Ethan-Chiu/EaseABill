from flask import Flask

app = Flask(__name__)

@app.route("/expenses")
def hello_world():
    return "<p>We good start up!</p>"