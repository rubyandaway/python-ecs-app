import time
import boto3
import requests
import os
from flask import Flask, session, url_for, redirect, render_template, request, abort, flash

app = Flask(__name__)
BACKEND_URL = os.environ.get("BACKEND_URL", default="http://localhost:5000")

@app.errorhandler(401)
def FUN_401(error):
    return render_template("page_401.html"), 401

@app.errorhandler(403)
def FUN_403(error):
    return render_template("page_403.html"), 403

@app.errorhandler(404)
def FUN_404(error):
    return render_template("page_404.html"), 404

@app.errorhandler(405)
def FUN_405(error):
    return render_template("page_405.html"), 405

@app.errorhandler(413)
def FUN_413(error):
    return render_template("page_413.html"), 413

@app.route("/")
def FUN_root():
    return render_template("index.html", backend=BACKEND_URL)

@app.route("/checkin", methods=['POST'])
def FUN_checkin():
    username = request.form['checkin']
    url = BACKEND_URL + '/api/v1/check/in/'
    data = {'user': username}
    response = requests.post(url, data=data)
    if response.status_code == 200 :
        return render_template("checkin.html")
    return render_template("checkin_error.html")

@app.route("/checkout", methods=['POST'])
def FUN_checkout():
    username = request.form['checkout']
    url = BACKEND_URL + '/api/v1/check/out/'
    data = {'user': username}
    response = requests.post(url, data=data)
    if response.status_code == 200 :
        return render_template("checkout.html")
    return render_template("checkout_error.html")

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
