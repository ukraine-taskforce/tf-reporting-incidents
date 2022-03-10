CREATE SCHEMA IF NOT EXISTS ugt;

create table ugt.user
(
    id            uuid not null
        constraint user_pk
            primary key,
    external_id   varchar(30) not null,
    language_code varchar(10),
    score         numeric(2) not null,
    created_on    timestamp with time zone not null,
    blacklisted   bool default 'f'
);

create table ugt.incident
(
    id                 uuid                     not null
        constraint incident_pk
            primary key,
    incident_timestamp timestamp with time zone not null,
    incident_type      varchar(30)              not null,
    location_lat       double precision,
    location_lon       double precision,
    location           point,
    distance           varchar(30),
    status             varchar(30)              not null,
    score              numeric(2)               not null,
    blacklisted        bool default 'f' not null,
    created_on         timestamp with time zone not null
);

CREATE INDEX idx_incident_timestamp ON ugt.incident(incident_timestamp);

create table ugt.incident_user
(
    user_id     uuid
        constraint incident_user___fk_user
            references ugt."user",
    incident_id uuid
        constraint incident_user___fk_incident
            references ugt.incident
);