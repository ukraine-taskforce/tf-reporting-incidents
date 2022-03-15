require('aws-sdk');

exports.handler = async (event) => {
    const dataClient = require('data-api-client')({
        secretArn: process.env.SECRET_ARN,
        resourceArn: process.env.RDS_DB_ARN,
        database: 'postgres'
    });

    const filter = event.queryStringParameters;
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Origin': '*'
        },
        body: mapOutput(await selectIncidents(dataClient, filter))
    };
}

const mapOutput = (incidents = []) => {
    return JSON.stringify(incidents.map(i => {
        return {
            timestamp: i.incident_timestamp,
            type: i.incident_type,
            time: i.time,
            location: {
                lat: i.location_lat,
                lon: i.location_lon
            },
            distance: i.distance,
            score: i.score
        }
    }));
}

const selectIncidents = async (dataClient, filter) => {
    let selectIncidentQuery = 'SELECT * FROM ugt.incident WHERE 1 = 1';
    const queryParams = {};

    if(filter && filter.type) {
        selectIncidentQuery += ' AND incident_type = :incident_type';
        queryParams['incident_type'] = filter.type;
    }

    if(filter && filter.timestampFrom) {
        selectIncidentQuery += ' AND incident_timestamp >= :timestamp_from::timestamp';
        queryParams['timestamp_from'] = filter.timestampFrom;
    }

    if(filter && filter.timestampTo) {
        selectIncidentQuery += ' AND incident_timestamp <= :timestamp_to::timestamp';
        queryParams['timestamp_to'] = filter.timestampTo;
    }

    selectIncidentQuery += ' ORDER BY incident_timestamp desc';

    return (await dataClient.query(selectIncidentQuery, queryParams)).records;
}
