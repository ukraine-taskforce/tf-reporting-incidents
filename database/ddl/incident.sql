create table ugt.incident
(
    id            uuid
        constraint incident_pk
            primary key,
    timestamp     timestamp   not null,
    incident_type varchar     not null,
    location_lat  varchar,
    location_long varchar,
    distance      varchar(30),
    validity      varchar(30) not null,
    created_on    timestamp   not null
);