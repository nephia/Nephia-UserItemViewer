package UserItemViewer;
use strict;
use warnings;
use Nephia plugins => [qw/Teng FormValidator::Lite/];

our $VERSION = 0.01;

use constant {
    PAGE_LIMIT => 5
};

database_do <<'SQL';
CREATE TABLE IF NOT EXISTS `user_item` (
    user_id INTEGER,
    item_id INTEGER,
    amount INTEGER,
    PRIMARY KEY (user_id, item_id)
);
SQL

database_do <<'SQL';
CREATE TABLE IF NOT EXISTS `user` (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
);
SQL

database_do <<'SQL';
CREATE TABLE IF NOT EXISTS `item` (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
);
SQL


# fixture and master data
database_do q{ INSERT OR REPLACE INTO user_item VALUES (1, 1, 10) };
database_do q{ INSERT OR REPLACE INTO user_item VALUES (2, 1, 1) };
database_do q{ INSERT OR REPLACE INTO user_item VALUES (1, 2, 2) };
database_do q{ INSERT OR REPLACE INTO user_item VALUES (1, 3, 5) };
database_do q{ INSERT OR REPLACE INTO user_item VALUES (2, 3, 10) };
database_do q{ INSERT OR REPLACE INTO user_item VALUES (3, 1, 4) };
database_do q{ INSERT OR REPLACE INTO user_item VALUES (3, 2, 0) };

database_do q{ INSERT OR REPLACE INTO user VALUES (1, 'bob') };
database_do q{ INSERT OR REPLACE INTO user VALUES (2, 'alice') };
database_do q{ INSERT OR REPLACE INTO user VALUES (3, 'john') };

database_do q{ INSERT OR REPLACE INTO item VALUES (1, 'meat') };
database_do q{ INSERT OR REPLACE INTO item VALUES (2, 'beer') };
database_do q{ INSERT OR REPLACE INTO item VALUES (3, 'apple') };

for my $url (qw{
    /
    /page/:page
    /user/:user_id
    /user/:user_id/page/:page
    /item/:item_id
    /item/:item_id/page/:page
}) {
    get $url => sub {
        my $page = path_param('page') || 1;
        return res { 404 } if ($page !~ /^[0-9]+$/);
        my $user_id = path_param('user_id');
        return res { 404 } if defined $user_id && ($user_id !~ /^[0-9]+$/);
        my $item_id = path_param('item_id');
        return res { 404 } if defined $item_id && ($item_id !~ /^[0-9]+$/);

        my $query = {
            'user_item.amount' => { '>' => 0 }
        };
        if (defined $user_id) {
            $query->{'user_item.user_id'} = $user_id;
        }
        if (defined $item_id) {
            $query->{'user_item.item_id'} = $item_id;
        }

        my $itr =
            teng->search_joined(user_item => [
                user => {'user_item.user_id' => 'user.id'},
                item => {'user_item.item_id' => 'item.id'},
            ],
            $query,
            {
                order_by => 'amount DESC',
                limit => PAGE_LIMIT,
                offset => PAGE_LIMIT * ($page - 1)
            },
        );
        return res { 404 } unless $itr;

        my $count = teng->count('user_item', '*', $query);
        my $max_page = int($count / PAGE_LIMIT) + 1;

        my $user_itr = teng->search('user');
        my $item_itr = teng->search('item');

        return {
            template  => 'index.html',
            title     => config->{appname},
            itr       => $itr,
            max_page  => $max_page,
            this_page => $page,
            user_itr  => $user_itr,
            item_itr  => $item_itr,
            user_id   => $user_id,
            item_id   => $item_id,
        };
    };
}

get '/user/:user_id/item/:item_id/:func' => sub {
    my $user_id = path_param('user_id');
    my $item_id = path_param('item_id');
    my $func = path_param('func');
    return res { 404 } unless  $user_id =~ /^[0-9]+/ && $user_id =~ /^[0-9]+/;
    return res { 404 } unless grep { $func eq $_ } qw/plus minus/;

    my $query = $func eq 'plus' ? { amount => \'amount + 1' } : { amount => \'amount - 1' };
    my $cond = { user_id => $user_id, item_id => $item_id };
    $cond->{amount} = { '>' => 0 } if $func eq 'minus';
    unless (teng->update('user_item', $query, $cond)) {
        return res { 404 };
    }

    res {
        req->referer ? redirect(req->referer) : redirect('/');
    };
};

post '/user/register' => sub {
    my $user_name = param('user_name');
    return res { redirect('/') } unless $user_name =~ /^[a-zA-Z_]+$/;

    my $row = teng->lookup('user', { name => $user_name });

    if (!$row) {
        teng->fast_insert('user', { name => $user_name });
    }

    return res { redirect('/') };
};

post '/item/register' => sub {
    my $item_name = param('item_name');
    return res { redirect('/') } unless $item_name =~ /^[a-zA-Z_]+$/;

    my $row = teng->lookup('item', { name => $item_name });

    if (!$row) {
       teng->fast_insert('item', { name => $item_name });
    }

    return res { redirect('/') };
};

post '/user/add_item' => sub {
    my $user_id = param('user_id');
    my $item_id = param('item_id');
    return res { redirect('/') } unless $user_id =~ /^[0-9]+$/ && $user_id =~ /^[0-9]+$/;

    my $row =
        teng->lookup('user_item', {
            user_id => $user_id,
            item_id => $item_id,
        });

    if (!$row) {
       teng->fast_insert('user_item', {
           user_id => $user_id,
           item_id => $item_id,
           amount  => 1,
       });
    }
    elsif ($row->amount == 0) {
       teng->update('user_item', {
           amount => 1
       },
       {
           user_id => $user_id,
           item_id => $item_id,
       });
    }

    return res {
        req->referer ? redirect(req->referer) : redirect('/');
    };
};

1;

=head1 NAME

UserItemViewer - Sample Application uses Nephia::Plugin::Teng

=head1 SYNOPSIS

  $ cd UserItemViewer
  $ cpanm --installdeps .
  $ plackup app.psgi

=head1 DESCRIPTION

UserItemViewer is web application based Nephia.

=head1 AUTHOR

macopy

=head1 SEE ALSO

L<Nephia>

L<Nephia::Plugin::Teng>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
