$versions{'starter_routines.pl'} = '06.6.00.0000';

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
# Starter sections coordinate:
#       browser cookies, if any
#       server side cookies, if any
#       cart ID check and assignment
#
#

########################################################################
#                  agora_starter_section Subroutine
########################################################################

# starter section used by main cart script: agora.cgi

sub agora_starter_section {
    my ( $junk ) = q{};

    # help with robots hitting site. may not always work.
    if ( $sc_global_bot_tracker ==  1 ) {
        $cart_id = $form_data{'cart_id'} = q{};
        $cookie{'cart_id'} = q{};
        $sc_special_page_meta_tags .= $sc_robot_meta_tags;
        set_agora('BOT',1);
    }
    #reduces inheritances in sharing URLs with Cart IDs
    #resolves 99.9% or so of the problems.  IF same exact browser and configs, then can be seen/shared possibly
    elsif ( $sc_global_bot_tracker ne '1' ) {    # run only if not a bot
        $sc_special_page_meta_tags .= $sc_browser_meta_tags;

        if ( $cookie{'cart_id'} eq '' && $form_data{'cart_id'} eq '' ) {
            # new visitor
            assign_a_unique_shopping_cart_id();
            $cart_id_history .= 'set new cart value ';  #for debugging
            #codehook( 'got_a_new_cart' );
        }
        elsif ( ( $form_data{'cart_id'} eq '' && $cookie{'cart_id'} )
            || ( $cookie{'cart_id'} eq $form_data{'cart_id'} )
            ) {
            # returning visitor without Cart ID in link or both match
            $cart_id = $cookie{'cart_id'};
            $cart_id_history .= 'from cookie ';  #for debugging
            if ( $form_data{'cart_id'} eq '' ) { $form_data{'cart_id'} = $cookie{'cart_id'}; }
            check_server_cookies_first();
            SetCookies();
        }
        elsif ( ( $form_data{'cart_id'} )
                && ( $cookie{'cart_id'} ne $form_data{'cart_id'} )
                && ( !$ENV{'HTTPS'} )
                ) {
            # both Cart ID in link and Cookie exists but not matching. Not SSL
            # Lets Check server side cookies now
            check_server_cookies_first();
        }
        elsif ( $form_data{'cart_id'} && $ENV{'HTTPS'} )   {
            # Cart ID in link exists in SSL mode. SSL, allowance for shared SSL
            # Lets Check server side cookies now
            check_server_cookies_first();
        }
        else {
            assign_a_unique_shopping_cart_id();
        }
    }   # end of if not a bot

    if ( ( $sc_buySafe_is_enabled =~ /yes/ ) || ( $sc_completed_orders_are_enabled =~ /yes/ ) ) {
        if ( ( $agora{'BUYSAFE_ORDER_COMPLETED'} eq 'yes' ) || ( $agora{'AGORA_ORDER_COMPLETED'} eq 'yes' ) ) {
            unlink("$sc_server_cookie_path");
            if (-e "$sc_cart_path") {
                unlink("$sc_cart_path");
            }
            if (-e "$sc_verify_order_path") {
                unlink("$sc_verify_order_path");
            }
            assign_a_unique_shopping_cart_id();
        }
    }

    if ( $sc_global_bot_tracker ne '1' ) {
        agora_cookie_save();
    }

    $sc_header_printed = 0;
    #$are_any_query_fields_filled_in = 'no';
}

########################################################################
#                  print_agora_http_headers Subroutine
########################################################################

sub print_agora_http_headers {

    if ( $sc_header_status =~ /404|400|401|403|405|410/ ) {
        #no_cache(1);
        print header(-cookie=>[$cookie,$cookie2], -status=>"$sc_header_status", -X_Robots_Tag=>'noindex, nofollow, noarchive, noimageindex');
    }
    else {
        if ( $sc_use_no_cache_headers eq 'yes' ) {
            no_cache(1);
        }
        print header(-cookie=>[$cookie,$cookie2]);
    }

    $sc_header_printed = 1;
}

########################################################################
#                  api_starter_section Subroutine
########################################################################

# alternate starter section for PayPal Express API within agora.cgi

sub api_starter_section {
    local ($cookie) = q{};
    my ( $junk ) = q{};

    # now un-taint the value of $form_data{'affiliate'}
    if ( $form_data{'affiliate'} ) {
        if ( $form_data{'affiliate'} =~ /^([\w\-\=\+\/]+)/ ) {
            my $temp = "$1";
            if ( $form_data{'affiliate'} ne $temp ) { $form_data{'affiliate'} = q{}; }
            else { $form_data{'affiliate'} = $temp; }
        }
    }

    alias_and_override();

    # help with robots hitting site. may not always work.
    if ( $sc_global_bot_tracker ==  1 ) {
        ( $cart_id, $form_data{'cart_id'}, $cookie{'cart_id'} ) = q{};
        $sc_special_page_meta_tags .= $sc_robot_meta_tags;
        set_agora('BOT',1);
    }

    #reduces inheritances in sharing URLs with Cart IDs
    #resolves 99.9% or so of the problems.  IF same exact browser and configs, then can be seen/shared possibly
    if ( $sc_global_bot_tracker ne '1' ) {    # run only if not a bot
        $cookie{'cart_id'} = $form_data{'cart_id'};
        $sc_special_page_meta_tags .= $sc_browser_meta_tags;

        if ( $cookie{'cart_id'} eq '' && $form_data{'cart_id'} eq '' ) {
            # new visitor
            assign_a_unique_shopping_cart_id();
            $cart_id_history .= 'set new cart value ';  #for debugging of course
        }
        elsif ( ( $form_data{'cart_id'} eq '' && $cookie{'cart_id'} )
            || ( $cookie{'cart_id'} eq $form_data{'cart_id'} )
            )
        {
            # returning visitor without Cart ID in link or both match
            $cart_id = $cookie{'cart_id'};
            $cart_id_history .= 'from cookie '; #for debugging
            set_sc_cart_path();
            check_server_cookies_first();
        }
        elsif ( ( $form_data{'cart_id'} )
                && ( $cookie{'cart_id'} ne $form_data{'cart_id'} )
                && ( !$ENV{'HTTPS'} )
              ) {
            # both Cart ID in link and Cookie exists but not matching. Not SSL
            # Lets Check server side cookies now
            check_server_cookies_first();
        }
        elsif ( $form_data{'cart_id'} && $ENV{'HTTPS'} ) {
            # both Cart ID in link exists. SSL, allowance for shared SSL
            # Lets Check server side cookies now
            check_server_cookies_first();
        }
        else { # fail safe
            $cart_id = $form_data{'cart_id'};
            $cart_id_history .= 'set from form data ';  #for debugging
            set_sc_cart_path();
        }
    }  # end of if not a bot

    if ( ( $sc_buySafe_is_enabled =~ /yes/ ) && ( $sc_global_bot_tracker ne '1' ) ) {
        my $temp_buysafe_check = get_agora('BUYSAFE_ORDER_COMPLETED');
        if ( $temp_buysafe_check eq 'yes' ) {
            assign_a_unique_shopping_cart_id();
        }
    }
    if ( $sc_completed_orders_are_enabled =~ /yes/ ) {
        my $temp_complete_order_check = get_agora('AGORA_ORDER_COMPLETED');
        if ( $temp_complete_order_check eq 'yes' ) {
            assign_a_unique_shopping_cart_id();
        }
    }
    if ( $ENV{'HTTP_CLIENT_IP'} && $ENV{'HTTPS'} ) {
        set_agora('IP', "$ENV{'HTTP_CLIENT_IP'}");
    }
    elsif ( $ENV{'HTTP_X_FORWARDED_FOR'} && $ENV{'HTTPS'} ) {
        set_agora('IP', "$ENV{'HTTP_X_FORWARDED_FOR'}");
    }
    else {
        set_agora('IP', "$ENV{'REMOTE_ADDR'}");
    }
    if ( ($MOBILE == 1) && ( $sc_global_bot_tracker ne '1' ) ) {
        set_agora('MOBILE',1);
     }
     if ( ( $form_data{'affiliate'} ) && ( $sc_global_bot_tracker ne '1' ) ) {
        set_agora('AFFILIATE',$form_data{'affiliate'});
     }
     if ( ( $form_data{'member'} ) && ( $sc_global_bot_tracker ne '1' ) ) {
        set_agora('MEMBER',$form_data{'member'});
     }
     if ( ( $form_data{'pricing'} ) && ( $sc_global_bot_tracker ne '1' ) ) {
        set_agora('PRICING',$form_data{'pricing'});
     }
     if ( $sc_global_bot_tracker ne '1' ) {
        set_agora( 'BROWSER', $sc_visitor_browser_string );
        set_agora( 'HTTP_USER_AGENT', $sc_visitor_http_user_agent );
        agora_cookie_save();
     }
    $sc_header_printed = 1;
    $are_any_query_fields_filled_in = 'no';
}

########################################################################

1;
