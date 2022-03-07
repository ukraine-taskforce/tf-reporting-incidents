var AWS = require('aws-sdk');
var uuid = AWS.util.uuid;

// const signer = new AWS.RDS.Signer({
//   region: 'eu-central-1',
//   hostname: 'pgsqlproxy.proxy-cwyhfj73ds2h.eu-central-1.rds.amazonaws.com',
//   port: 5432,
//   username: 'root'
// });

const INSERT_INCIDENT = `INSERT INTO ugt.incident (id, incident_timestamp, incident_type, location_lat, location_long, distance, status, created_on) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`;
const INSERT_INCIDENT_USER = `INSERT INTO ugt.incident_user(user_id, incident_id) VALUES ($1, $2)`;

const INSERT_USER_QUERY = `INSERT INTO ugt.user(id, external_id, language_code, score, created_on) VALUES ($1, $2, $3, $4, $5)`;
const SELECT_USER_BY_EXTERNAL_ID = `SELECT * FROM ugt.user WHERE external_id = $1`;

exports.handler = async (event) => {
    // const authToken = signer.getAuthToken();
    // console.log('AuthToken:', authToken);

    const { Pool, Client } = require("pg");

    const eventBody = JSON.parse(event?.Records[0].body);

    const pool = new Pool({
        user: "root",
        host: "reporting-incidents-aurora-0.cwyhfj73ds2h.eu-central-1.rds.amazonaws.com",
        database: "postgres",
        password: "ZB2ys9D44Nj*54+g",
        port: "5432"
    });

    const client = await pool.connect();

    try {
        // Open transaction
        await client.query('BEGIN');

        const userId = await getOrCreateUser(client, eventBody);
        const incidentId = await createIncident(client, eventBody);
        await linkUser2Incident(client, userId, incidentId);

        await client.query('COMMIT');
    } catch (e) {
        await client.query('ROLLBACK');
        throw e
    } finally {
        client.release()
    }

    return { message: 'Successfully created item!' };
}

const getOrCreateUser = async (client, body) => {
    const inputUser = body.user;
    const user = await selectUserByExternalId(client, inputUser.id);
    if(user) return user.id;

    const userId = uuid.v4();
    const createUserQueryParams = [
        userId,
        inputUser.id,
        inputUser.language_code,
        0,
        new Date().toISOString()
    ];

    await client.query(INSERT_USER_QUERY, createUserQueryParams);
    return userId;
}

const selectUserByExternalId = async(client, externalId) => {
    const result = await client.query(SELECT_USER_BY_EXTERNAL_ID, [externalId]);

    if(result?.rowCount > 0) {
        return result?.rows[0];
    }

    return null;
}

const createIncident = async (client, body) => {
    const incidentId = uuid.v4();

    const inputIncident = body.incident;

    const createIncidentQueryParams = [
        incidentId,
        inputIncident.timestamp,
        inputIncident.type,
        inputIncident.location.lat,
        inputIncident.location.long,
        inputIncident.distance,
        'PENDING',
        new Date().toISOString()
    ];

    await client.query(INSERT_INCIDENT, createIncidentQueryParams);
    return incidentId;
}

const linkUser2Incident = async (client, userId, incidentId) => {
    const linkUserToIncidentQueryParams = [userId, incidentId];
    await client.query(INSERT_INCIDENT_USER, linkUserToIncidentQueryParams);
}
