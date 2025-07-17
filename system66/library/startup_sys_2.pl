$versions{'startup_sys_2.pl'} = '06.6.00.0000';

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
# A continuation of the startup process
# Put in separate file for easier readability.
#
#

#######################################################################

sub startupCart_stepTwo {

    # store for URL purposes, clean for data purposes
    if ( $form_data{'product'} ) {
      $form_data{'productURL'} = $form_data{'product'};
      $form_data{'product'} = query_by_URL_cleaner($form_data{'product'});
    }

    # store for URL purposes, clean for data purposes
    if ( $form_data{'name'} ) {
      $form_data{'nameURL'} = $form_data{'name'};
      $form_data{'name'} = query_by_URL_cleaner($form_data{'name'});
    }

    # store & clean for subcat Title purposes
    if ( ( $form_data{$sc_subcat_index_field} ) && ( $sc_use_database_subcats =~ /yes/i ) ) {
      $form_data{$sc_subcat_title_name} = $form_data{$sc_subcat_index_field};
      $form_data{$sc_subcat_title_name} = query_by_URL_cleaner($form_data{$sc_subcat_title_name});
    }
    else {
        $form_data{$sc_subcat_title_name} = '';
    }

    require_supporting_libraries( __FILE__, __LINE__,
        "$sc_store_HTML_framework",
        "$sc_store_HTML_includes",
        "$sc_template_widgets_file",
        "$sc_template_homezone_file",
        "$sc_lib_dir/MD5.pl",
        "$sc_db_lib_path"
    );

    # load payment gateways, as activated in manager settings
    # (no more dynamic loading or secondary gateways for security purposes - August 2017)
    foreach $zlib (@sc_active_gateways) {
        my $lib = $zlib . '-order_lib.pl';
        if ( -f "$sc_paygates_dir/$lib" ) {
            require_supporting_libraries( __FILE__, __LINE__, "$sc_paygates_dir/$lib" );
            $sc_gateway_count++;
        }
    }

    &run_freeform_logic();

    #require_supporting_libraries( __FILE__, __LINE__,
    #    "$sc_lib_dir/shipping-order-instructions-sort.pl"
    #);

    # load add-ons, as activated in manager settings, no more dynamic loading just by existence - August 2017
    foreach $zlib (@sc_active_plugins) {
        $lib = $zlib;
        if ( -f "$sc_add_on_modules_dir/$lib" ) {
            require_supporting_libraries( __FILE__, __LINE__, "$sc_add_on_modules_dir/$lib" );
        }
    }

    codehook( 'after_loading_custom_libs' );

    if ( ( $sc_debug_mode eq 'yes' ) && ( $sc_collect_test_data eq 'yes' ) ) {
        for my $keys45 (sort keys(%ENV)) {
            $sc_test_data_to_print .= "\$ENV{$keys45} = $ENV{$keys45}<br>\n";
        }
        $sc_test_data_to_print .= &debugGetFormKeysValues;
    }


    if (
         ( ( form_check('submit_order_form_button') ) && $form_data{'order_form'} && $form_data{'order_api_mode'} && $form_data{'gateway'} && ( $sc_API_access_gateways_allowed =~ /$form_data{'gateway'}/ ) && ( $sc_API_access_double_check_string =~ /$form_data{'order_api_mode'}/ ) )
         || ( ( $sc_global_bot_tracker ne '1' ) && $form_data{'shortcut_button'} && $form_data{'gateway'} && $form_data{'order_api_mode'} && ( $sc_API_access_gateways_allowed =~ /$form_data{'shortcut_button'}/ ) && ( $sc_API_access_gateways_allowed =~ /$form_data{'gateway'}/ ) && ( $sc_API_access_double_check_string =~ /$form_data{'order_api_mode'}/ ) )
        ) {
        api_starter_section();
    }

    # moved from regular starter section
    if ( $sc_global_bot_tracker ne '1' ) {
        $cookie{'cart_id'} = cookie('cart_id');
        $cookie{'affiliate'} = cookie('affiliate');
        if ( $cookie{'cart_id'} ) {
            &untaintCartIDCookie;
        }

        &swapCookieFormData('cart_id');

        if ( $cart_id eq $cookie{'cart_id'} ) {
            set_agora( 'BROWSER_COOKIES_ON', 'yes' );
        }
    }

    &alias_and_override;
    &check_for_site_page_requests;

    &run_freeform_logic_too();

    codehook( 'open_for_business' );

    foreach $query_field (@sc_db_query_criteria) {
        @criteria = split( /\|/, $query_field );
        if ( $form_data{ $criteria[0] } ) {
            $are_any_query_fields_filled_in = 'yes';
        }
    }

    if ( ( @sc_exact_query_criteria ) && ($are_any_query_fields_filled_in ne 'yes') ) {
        foreach $query_field (@sc_exact_query_criteria) {
            @criteria = split( /\|/, $query_field );
            if ( $form_data{ $criteria[0] } ) {
                $are_any_query_fields_filled_in = 'yes';
            }
        }
    }

    # do we need this anymore ??? Move it???
    if ( ( $search_request ) && ( $are_any_query_fields_filled_in eq 'no' ) )
    {
        $page   = 'searchpage.html';
        $search_request = q{};
        if ( !( -f "$sc_html_product_directory_path/$page" ) ) {
            $page  =  q{};
            $form_data{'product'}   = '.';     # show everything
            $are_any_query_fields_filled_in = 'yes';
        }
        else {
            $form_data{'page'} = $page;
        }
    }

    if ( ( $MOBILE == 1 || $form_data{'pricing'} || $form_data{'affiliate'} || $form_data{'member'} ) && ( $sc_global_bot_tracker ne '1' ) ) {
        agora_cookie_save();
    }

}

#######################################################################

1;
