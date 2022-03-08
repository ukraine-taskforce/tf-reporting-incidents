var AWS = require('aws-sdk');
var uuid = AWS.util.uuid;

const INSERT_INCIDENT = `INSERT INTO ugt.incident (id, incident_timestamp, incident_type, location_lat, location_long,
                                                   distance, status, score, created_on)
                         VALUES (:id::uuid, :incident_timestamp::timestamp, :incident_type, :location_lat,
                                 :location_long, :distance, :status, :score, :created_on::timestamp)`;
const INSERT_INCIDENT_USER = `INSERT INTO ugt.incident_user(user_id, incident_id)
                              VALUES (:user_id::uuid, :incident_id::uuid)`;

const INSERT_USER_QUERY = `INSERT INTO ugt.user(id, external_id, language_code, score, created_on)
                           VALUES (:id::uuid, :external_id, :language_code, :score, :created_on::timestamp)`;
const SELECT_USER_BY_EXTERNAL_ID = `SELECT *
                                    FROM ugt.user
                                    WHERE external_id = :externalId`;

exports.handler = async (event) => {
    // Parse body of message object
    const eventBody = JSON.parse(event?.Records[0].body);

    const dataClient = require('data-api-client')({
        secretArn: process.env.SECRET_ARN,
        resourceArn: process.env.RDS_DB_ARN,
        database: 'postgres'
    });

    const userId = await getOrCreateUser(dataClient, eventBody);
    await createIncident(dataClient, userId, eventBody);

    return {message: 'Successfully created item!'};
}

const getOrCreateUser = async (client, body) => {
    const inputUser = body.user;
    const user = await selectUserByExternalId(client, inputUser.id);
    if (user) return user.id;

    const userId = uuid.v4();
    const createUserQueryParams = {
        id: userId,
        external_id: inputUser.id,
        language_code: inputUser.language_code,
        score: 0,
        created_on: new Date().toISOString()
    };

    await client.query(INSERT_USER_QUERY, createUserQueryParams);
    return userId;
}

const selectUserByExternalId = async (dataClient, externalId) => {
    const result = await dataClient.query(SELECT_USER_BY_EXTERNAL_ID, {externalId});

    if (result.records.length > 0) {
        return result.records[0];
    }

    return null;
}

const createIncident = async (dataClient, userId, eventBody) => {
    const incidentId = uuid.v4();

    const inputIncident = eventBody.incident;
    const createIncidentQueryParams = {
        id: incidentId,
        incident_timestamp: inputIncident.timestamp,
        incident_type: inputIncident.type,
        location_lat: inputIncident.location.lat,
        location_long: inputIncident.location.long,
        distance: inputIncident.distance,
        status: 'PENDING',
        score: 0,
        created_on: new Date().toISOString()
    };

    await dataClient.transaction()
        .query(INSERT_INCIDENT, createIncidentQueryParams)
        .query(INSERT_INCIDENT_USER, {user_id: userId, incident_id: incidentId})
        .rollback((e, status) => {
            throw e
        })
        .commit();
}
