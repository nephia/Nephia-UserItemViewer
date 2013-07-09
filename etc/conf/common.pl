### common config
use utf8;
+{
    'Plugin::Teng' => {
        connect_info => ['dbi:SQLite:dbname=data/data.db'],
        plugins => [qw/Lookup SearchJoined Count/]
    },
};
