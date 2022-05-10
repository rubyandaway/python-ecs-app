import time
import boto3
import controller
from flask import Flask, request, jsonify
from flask_cors import CORS

dynamo_client = boto3.client('dynamodb')

app = Flask(__name__)
CORS(app)

@app.route('/')
def loaded():
    return 'HEALTHY'

@app.route('/api/v1/check/out/', methods=['POST'])
def check_out():
    user = request.form['user']
    response = jsonify(controller.check_out_user(user))
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response

@app.route('/api/v1/check/in/', methods=['POST'])
def check_in():
    user = request.form['user']
    response = jsonify(controller.check_in_user(user))
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response

@app.route('/api/v1/get/<user>')
def status(user):
    response = jsonify(controller.is_user_checked_in(user))
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response

@app.route('/api/v1/get')
def get_users():
    response = jsonify(controller.get_users())
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
