var AWS = require('aws-sdk'),
    uuid = AWS.util.uuid,
    dynamoDbDocumentClient = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    var params = {
        Item: {
            'id': uuid.v4(),
            'body': JSON.parse(event?.Records[0].body),
            'createdOn': new Date().toISOString()
        },
        TableName: process.env.TABLE_NAME
    };

    try {
        await dynamoDbDocumentClient.put(params).promise();
        return { message: 'Successfully created item!' }
    } catch (err) {
        console.error('Event: ', event);
        return { message: err }
    }
}