create table ugt.incident
(
    id                 uuid                     not null
        constraint incident_pk
            primary key,
    incident_timestamp timestamp with time zone not null,
    incident_type      varchar                  not null,
    location_lat       varchar,
    location_long      varchar,
    distance           varchar(30),
    status             varchar(30)              not null,
    created_on         timestamp with time zone not null
);