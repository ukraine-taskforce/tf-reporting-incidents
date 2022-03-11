exports.handler = async (event) => {

    console.log('Authorizer event: ', event);

    const auth = event.authorizationToken === '123' ? 'Allow' : 'Deny';

    return {
        principalId: "abc123",
        policyDocument: {
            Version: "2012-10-17",
            Statement: [
                {
                    Action: "execute-api:Invoke",
                    Resource: [
                        event.methodArn
                    ],
                    Effect: auth
                }
            ]
        }
    };
}
