import boto3
from boto3.dynamodb.conditions import Key, Attr

dynamo_resource = boto3.resource('dynamodb')
table = dynamo_resource.Table('UserCheckin')

def get_users():
    return table.scan()

def check_in_user(username):
    if user_exists(username):
        table.update_item(
            Key={
                'Username': username
            },
            UpdateExpression='set CheckedIn=:i, CheckedOut=:o',
            ExpressionAttributeValues={
                ':i': True,
                ':o': False
            }
        )
    else:
        table.put_item(
            Item={
                    'Username': username,
                    'CheckedIn': True,
                    'CheckedOut': False
                 }
        )
    return table.get_item(
            Key={
                'Username': username
            }
        )

def check_out_user(username):
    if user_exists(username):
        table.update_item(
            Key={
                'Username': username
            },
            UpdateExpression='set CheckedIn=:i, CheckedOut=:o',
            ExpressionAttributeValues={
                ':i': False,
                ':o': True
            }
        )
    else:
        table.put_item(
            Item={
                    'Username': username,
                    'CheckedIn': False,
                    'CheckedOut': True
                 }
        )
    return table.get_item(
            Key={
                'Username': username
            }
        )

def is_user_checked_in(username):
    if user_exists(username):
        response = table.get_item(
            Key={
                'Username': username
            }
        )
        return response['Item']['CheckedIn']
    return False

def user_exists(username):
    response = table.get_item(
        Key={
            'Username': username
        }
    )
    if 'Item' in response:
        return True
    return False

