exports.handler = async (event) => {

    console.log('Authorizer event: ', event);

    const auth = event.authorizationToken === '3a0ac513178a9a227657432f7030f5c4' ? 'Allow' : 'Deny';

    return {
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
