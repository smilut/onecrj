CREATE TABLE log_storage.simple_onec_log
(
    `Application` LowCardinality(String),
    `ApplicationName` LowCardinality(String),
    `Comment` String CODEC(ZSTD(1)),
    `Computer` String,
    `ComputerName` String,
    `Connection` String,
    `Data` String CODEC(ZSTD(1)),
    `DataPresentation` String CODEC(ZSTD(1)),
    `DataRef` String,
    `DataType` LowCardinality(String),
    `DataTypeName` LowCardinality(String),
    `Date` DateTime('UTC') CODEC(Delta(4), LZ4),
    `DateLocal` DateTime('UTC') CODEC(Delta(4), LZ4),
    `Event` String,
    `EventName` LowCardinality(String),
    `Infobase` LowCardinality(String),
    `Level` LowCardinality(String),
    `LevelName` LowCardinality(String),
    `Metadata` String,
    `MetadataName` LowCardinality(String),
    `MetadataUuid` String,
    `Port` String,
    `PortNumber` String,
    `Server` LowCardinality(String),
    `ServerName` LowCardinality(String),
    `Session` String,
    `SyncPort` String,
    `TransactionID` String,
    `TransactionStatus` LowCardinality(String),
    `TransactionStatusName`  LowCardinality(String),
    `User` LowCardinality(String),
    `UserName` LowCardinality(String),
    `UserUUID` LowCardinality(String),
    `timestamp` DateTime,
    `file` String CODEC(ZSTD(1)),
    `message` String CODEC(ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(Date)
PRIMARY KEY (Infobase, Date)
ORDER BY (Infobase, Date)
TTL Date + toIntervalYear(2)
SETTINGS index_granularity = 8192;

--ALTER TABLE log_storage.simple_onec_log ADD INDEX iByEvent (Infobase, Date, Event);