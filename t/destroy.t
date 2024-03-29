#!/usr/bin/perl

use warnings;
use strict;

use Test::More;
use t::Util;

use B::Hooks::AtRuntime;

my $cl = "closed-over values";

{
    @::D = ();
    fakerequire "req", q{
        use t::D "req";
        ok !@::D, "closed over values in require persist while " .
            "require is running";
        1;
    };
    
    is_deeply \@::D, ["req"],
        "closed-over values in require freed when require ends";
}

unless (B::Hooks::AtRuntime::USE_FILTER) {
    @::D = ();
    eval q{
        use t::D "eval";
        ok !@::D, "$cl in eval persist while eval is running";
        1;
    };

    is_deeply \@::D, ["eval"],
        "$cl in eval freed when eval ends";
}

{
    @::D = ();
    fakerequire "undef", q{
        sub sub_undef {
            use t::D "undef";
        }
        1;
    };

    ok !@::D,   "$cl in a named sub remain while the sub exists";

    undef &{"sub_undef"};
    is_deeply \@::D, ["undef"],      
        "$cl in a named sub freed when the sub is undefed";
}

{
    @::D = ();
    fakerequire "redef", q{
        sub sub_redef {
            use t::D "redef";
        }
        1;
    };

    {
        no warnings "redefine";
        no strict "refs";
        *{"sub_redef"} = sub { 1 };
    }

    is_deeply \@::D, ["redef"],
        "$cl in a named sub freed when the sub is redefined";
}

{
    @::D = ();
    fakerequire "stashdel", q{
        sub sub_stashdel {
            use t::D "stashdel";
        }
        1;
    };

    delete $::{sub_stashdel};
    is_deeply \@::D, ["stashdel"],
        "$cl in a named sub freed when stash is deleted";
}

{
    @::D = ();
    fakerequire "stashdel2", q{
        sub sub_stashdel2 {
            use t::D "stashdel2";
        }
        sub use_stashdel { sub_stashdel2 }
        1;
    };

    delete $::{sub_stashdel2};
    ok !@::D, "$cl in stash-deleted named sub remain if more refs";

    undef &use_stashdel;
    is_deeply \@::D, ["stashdel2"],
        "$cl in a stash-deleted named sub freed when no more refs";
}

{
    @::D = ();
    fakerequire "anonsub", q{
        {
            my $dummy = sub {
                use t::D "anonsub";
            };
        }

        sub anonsub_proto {
            sub {
                use t::D "anonsub proto";
            };
        }

        sub anonsub_ref {
            sub {
                use t::D "anonsub ref";
            };
        }

        1;
    };

    {
        local $TODO = "anon subs pin their parents (core bug, I think)";
        ok grep($_ eq "anonsub", @::D),
            "$cl in anon sub freed when surrounding scope freed";
    }

    ok !grep($_ eq "anonsub proto", @::D),
        "$cl in anon sub persist while prototype exists";

    undef &anonsub_proto;
    ok grep($_ eq "anonsub proto", @::D),
        "$cl in anon sub freed when prototype freed";

    my $cv = anonsub_ref();
    undef &anonsub_ref;
    ok !grep($_ eq "anonsub ref", @::D),
        "$cl in anon sub persist while instances exist";
    
    undef $cv;
    ok grep($_ eq "anonsub ref", @::D),
        "$cl in anon sub freed when last instance freed";
}

done_testing;
