$versions{'cookies_sessions_cart_ids.pl'} = '06.6.00.0000';

#######################################################################
#
# AgoraCart and all associated files, except where noted, are
# Copyright 2001 to Present jointly by K-Factor Technologies, Inc.
# and by C E Mayo (aka Mister Ed) at AgoraCart.com & K-Factor.net
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This copyright notice may not be removed or altered in any way.
#
#######################################################################


#
#
# Contains the functions/routines needed to establish for each visitor:
#     unique cart_id
#     cookies (get and set)
#     set cart path for ordering processes
#     get and set server side cookies/sessions
#
#

#######################################################################
#                        Assign a Shopping Cart
#######################################################################
#
# assign_a_unique_shopping_cart_id is a subroutine used to
# assign a unique cart id to every new client.  It takes
# no arguments and is called with the following syntax:
#
# assign_a_unique_shopping_cart_id();
#
#######################################################################

sub assign_a_unique_shopping_cart_id {

    # Since no cart_id cookie exists, the script assigns
    # the user their own unique shopping cart.  To do so,
    # it generates a random (rand) 9 digit (1000000000)
    # integer (int) and then appends to that string the current
    # process id ($$). However, the srand function is seeded
    # with the time and the current process id in order to
    # produce a more random random number.  $sc_cart_path is
    # also defined now that we have a unique cart id number.
    srand( time | $$ );
    if ( $sc_need_short_cart_id =~ /yes/i ) {
        $cart_id = int( rand(100000) );
    }
    else {
        $cart_id = int( rand(1000000000) );
    }
    $cart_id .= ".$$";
    $cart_id =~ s/-//g;

    codehook( 'assign-cart_id-modifier' );

    $sc_cart_path = "$sc_user_carts_directory_path/${cart_id}_cart";

    # However, before we can be absolutely sure that we have
    # created a unique cart, the script must check the existing
    # list of carts to make sure that there is not one with
    # the same value.
    #
    # It does this by checking to see if a cart with the
    # randomly generated ID number already exists in the Carts
    # directory.  If one does exit (-e), the script grabs
    # another random number using the same routine as
    # above and checks again.
    #
    # Using the $cart_count variable, the script executes this
    # algorithm three times.  If it does not succeed in finding
    # a unique cart id number, the script assumes that there is
    # something seriously wrong with the randomizing routine
    # and exits, warning the user on the web and the admin
    # using the update_error_log subroutine discussed later.
    $cart_count = 0;

    while ( -e "$sc_cart_path" ) {
        if ( $cart_count == 4 ) {
            print "$sc_randomizer_error_message";
            update_error_log( "$agora_error_logging_notice01",__FILE__, __LINE__ );
            call_exit();
        }
        srand( time | $$ );
        $cart_id = int( rand(1000000000) );
        $cart_id .= ".$$";
        $cart_id =~ s/-//g;

        codehook( 'assign-cart_id-modifier' );

        $sc_cart_path = "$sc_user_carts_directory_path/${cart_id}_cart";
        $cart_count++;

    }    # End of while (-e $sc_cart_path)

    # Now that we have generated a truly unique id
    # number for the new client's cart, the script may go
    # ahead and create it in the shopping_sessions sub-directory.
    &set_sc_cart_path;  # there are other paths that must be set as well
    codehook("assign-cart_id");
    SetCookies();

}

#######################################################################

#
#
#
#
#


#######################################################################

sub set_sc_cart_path {
    local ($raw_text) = q{};
    local ($base)     = q{};

    # have already untainted $cart_id, this should be all we need to do
    $base                  = "$sc_user_carts_directory_path/";
    $sc_cart_path          = "$base${cart_id}_cart";
    $sc_capture_path       = "$base${cart_id}_CAPTURE";
    $sc_server_cookie_path = "$base${cart_id}_COOKIES";
    $sc_verify_order_path  = "$base${cart_id}_VERIFY";
    $cart_id_for_html      = "$cart_id";

    #codehook('before_server_cookie_load');

    $sc_server_cookies_loaded = '';

    if ( -e "$sc_server_cookie_path" && -r "$sc_server_cookie_path" ) {
        # file is there, now try to require it in a not-fatal way
        #undef(%agora);
        undef(%agora_original_values);
        eval('require "$sc_server_cookie_path"');
        $sc_server_cookies_loaded = '1';
    }
    require_supporting_libraries( __FILE__, __LINE__,"$sc_userlog_settings" );

    if ( get_agora('LAST_VISIT_TIMESTAMP') eq '' ) {    # new shopping session
        if ( $sc_shall_i_log_accesses eq 'yes' ) {
            log_access_to_store();
        }

        set_agora( 'HTTP_USER_AGENT', $sc_visitor_http_user_agent );
        set_agora( 'BROWSER', $sc_visitor_browser_string );
        if ($MOBILE == 1) { set_agora('MOBILE',1); }

        if ( $ENV{'HTTP_CLIENT_IP'} && $ENV{'HTTPS'} && $ENV{'REMOTE_ADDR'} eq '' ) {
            set_agora('IP', "$ENV{'HTTP_CLIENT_IP'}");
        }
        elsif ( $ENV{'HTTP_X_FORWARDED_FOR'} && $ENV{'HTTPS'} && $ENV{'REMOTE_ADDR'} eq '' ) {
            set_agora('IP', "$ENV{'HTTP_X_FORWARDED_FOR'}");
        }
        else {
            set_agora('IP', "$ENV{'REMOTE_ADDR'}");
        }
    }

    set_agora( 'AFFILIATE', $form_data{'affiliate'} );
    set_agora( 'LAST_VISIT_TIMESTAMP', time() );

    #codehook('after_server_cookie_load');

    $sc_test_repeat = 0;
    $raw_text = get_agora('TRANSACTIONS');
    if ( $sc_unique_cart_modifier ne '' ) {
        if ( !( $raw_text =~ /$sc_unique_cart_modifier/ ) ) {
            set_agora( 'TRANSACTIONS',
                $raw_text . "$sc_unique_cart_modifier\n" );
        }
        else {
            $sc_test_repeat = 1;
        }
    }

    #codehook( 'set_sc_cart_path_bot' );
    return;
}

#######################################################################

#
#
#
#
#

#######################################################################

# added to check server side cookies to determine if cart ID in link matches up

sub check_server_cookies_first {
    my $testip = $ENV{'REMOTE_ADDR'};

    &set_sc_cart_path;

    if ( $ENV{'HTTP_X_FORWARDED_FOR'} && $ENV{HTTPS} eq 'on' && $ENV{'REMOTE_ADDR'} eq '' ) {
        if ( !($agora{'IP'}) ) { set_agora('IP', "$ENV{'HTTP_X_FORWARDED_FOR'}"); }
        $testip = $ENV{'HTTP_X_FORWARDED_FOR'};
    }
    elsif ( $ENV{'HTTP_CLIENT_IP'} && $ENV{'HTTPS'} eq 'on' && $ENV{'REMOTE_ADDR'} eq '' ) {
        if ( !($agora{'IP'}) ) { set_agora('IP', "$ENV{'HTTP_CLIENT_IP'}"); }
        $testip = $ENV{'HTTP_CLIENT_IP'};
    }

    if (
        ( ( $sc_visitor_http_user_agent ne $agora{'HTTP_USER_AGENT'} )
        || ( $agora{'IP'} ne $testip )
        || ( $agora{'BROWSER'} ne $sc_visitor_browser_string ) )
        || ( $agora{'BUYSAFE_ORDER_COMPLETED'} =~ /yes/i )
        || ( $agora{'AGORA_ORDER_COMPLETED'} =~ /yes/i )
       )  {
        ( $form_data{'order_form_button'}, $form_data{'order_form_button.x'} ) =  q{};
        ( $form_data{'cart_id'}, $cart_id, $cart_id_for_html ) = q{};
        undef(%agora);
        undef(%agora_original_values);
        unlink("$sc_server_cookie_path");
        if (-e "$sc_cart_path") {
            unlink("$sc_cart_path");
        }
        if (-e "$sc_verify_order_path") {
            unlink("$sc_verify_order_path");
        }
        &assign_a_unique_shopping_cart_id;
    }

    return;
}

#######################################################################

#
#
#
#
#

#######################################################################

sub SetCookies {
    local ( $junk ) = q{};
    local ( $cookie_domain, $cookie_secure_status ) = q{};
    local $cookie_http_only = '1';
    ( $cookie{'cart_id'}, $junk ) = split( /\*/, $cart_id, 2 );

    if ( ( $ENV{HTTPS} eq 'on' ) || ( $form_data{'secure'} ) ) {
        $cookie_domain = $sc_secure_domain_name_for_cookie;
        $cookie_secure_status = '1';
    }
    else {
        $cookie_domain = $sc_domain_name_for_cookie;
        $cookie_secure_status = '0';
    }

    if ( $sc_onlyHttpCookies eq 'no' ) {
        $cookie_http_only = '0';
    }

    codehook( 'about_to_set_cookie' );

    $cookie = cookie(-name=>'cart_id',
        -value=>"$cookie{'cart_id'}",
        -expires=>'+29d',
        -path=>"$sc_path_for_cookie",
        -domain=>"$cookie_domain",
        -secure=>"$cookie_secure_status",
        -httponly=>"$cookie_http_only"
    );
    if ( $form_data{'affiliate'} ) {
        $cookie2 = cookie(-name=>'affiliate',
            -value=>"$form_data{'affiliate'}",
            -expires=>'+90d',
            -path=>"$sc_path_for_cookie",
            -domain=>"$cookie_domaine",
            -secure=>"$cookie_secure_status",
            -httponly=>"$cookie_http_only"
        );
    }
}

#######################################################################

sub agora_cookie_save {

    local ($inx,$temp, $result) = q{};
    local (@test,$temp_cookie_jar,$cart_abandon_point,@rows) = q{};
    my $sql_temp_table = "serverside_cookies"; #sqlupdate

    # Debug item
    if ( $sc_debug_mode =~ /yes/i ) {
        foreach my $inx ( keys %form_data ) {
            $temp .= "$inx\x01$form_data{$inx}\x01";
        }
        &set_agora( "PREVIOUS_FORM_VALUES", $temp );
    }

    # check for abandon point
    if ( ( form_check('display_cart') ) || ( $form_data{'dc'} ) ) {
        $cart_abandon_point = 'CARTDISPLAY';
    }
    elsif ( form_check('add_to_cart_button') ) {
        $cart_abandon_point = 'ADDTOCART';
    }
    elsif ( ( form_check('modify_cart_button') ) || ( form_check('submit_change_quantity_button') ) || ( form_check('submit_deletion_button') ) ) {
        $cart_abandon_point = 'CARTEDIT';
    }
    elsif ( ( form_check('order_form_button') ) || ( form_check('clear_order_form_button') ) ) {
        $cart_abandon_point = 'ORDERFORM';
    }
    elsif ( form_check('submit_order_form_button') ) {
        $cart_abandon_point = 'ORDERFORM';
    }

    # set abandon point
    if ( $cart_abandon_point ) {
        &set_agora( "ABANDON_POINT", $cart_abandon_point );
    }

    # start sqlupdate
    if ( $sc_database_libNOTREADY eq "$sc_database_sql_option_lib" ) {
        foreach $inx (sort(keys %agora)) {
            $temp = &str_encode($agora{$inx});
            if ($temp =~ /\%/) {
               $temp_cookie_jar .= "$inx = sub_str_decode" .
               &str_encode($agora{$inx}) . "\n";
            } else {
               $temp_cookie_jar .=  "$inx = " .
               $agora{$inx} . "\n";
            }
        }

       my $agcookies = agcookies->new($sql_username,$sql_password,$sql_database,$sql_temp_table);
       $agcookies->connectdb;
       $result = $agcookies->checkkey("$cart_id");
       $agcookies>disconnectdb;

       if ($result ne 0) {
          @rows = $agcookies->getagrow();
          $test[4] = "$rows[0][4]";
          $test[4]++;
       } else { $test[3] = time; }

      $test[0] = "$cart_id";
      $test[1] = qq|$temp_cookie_jar|;
      $test[5] = time;

      if ($result ne 0) {
          $agcookies->editrow(@test);
      } else {
          $test[4] = 1;
          $agcookies->addrow(@test);
      }
    }
    #end sqlupdate
    else { # original stuff
        open( SERVCOOKIE, ">$sc_server_cookie_path" );
        print SERVCOOKIE "# Library of agora.cgi Server Cookies\n";
        foreach my $inx ( sort( keys %agora ) ) {
            $temp = &str_encode( $agora{$inx} );
            if ( $temp =~ /\%/ ) {
                print SERVCOOKIE "\$agora{'$inx'} = str_decode('"
                  . &str_encode($agora{$inx}) . "');\n";
            }
            else {
                print SERVCOOKIE "\$agora{'$inx'} = '" . $agora{$inx} . "';\n";
            }
        }
        print SERVCOOKIE '{local($inx);'
          . 'foreach $inx (keys %agora) {'
          . '$agora_original_values{$inx} = $agora{$inx};}' . "}\n";
        print SERVCOOKIE "#\n1;\n";
        close(SERVCOOKIE);
    }
    # end original stuff
}

#######################################################################
1;
