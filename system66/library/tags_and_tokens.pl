$versions{'tags_and_tokens.pl'} = '06.6.00.0002';

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
# Contains the subroutines/functions for parsing embedded tags and tokens within
# templates that are used site wide.
#
#

########################################################################
#                  script_and_substitute Subroutine
########################################################################

sub script_and_substitute {
    local ( $the_file, $page ) = @_;
    local ( $href_fields, $hidden_fields, $item_ordered_message, $my_text ) = '';
    local ( $arg, $myans );

    $href_fields      = make_href_fields();
    $hidden_fields    = make_hidden_fields();
    $cart_id_for_html = '[[ZZZ]]';

    # All forms must include at least two hidden field lines
    # with "tags" to be substituted for embedded as follows:
    #
    # <INPUT TYPE = "hidden" NAME = "cart_id" VALUE = "[[cart_id]]">
    # <INPUT TYPE = "hidden" NAME = "page" VALUE = "[[page]]">
    #
    # When the script reads in these lines, it will see the
    # tags "[[cart_id]]" and"[[page]]" and substitute them for
    # the actual page and cart_id values which came in as form
    # data.
    #
    # Similarly it might see the following URL reference:
    #
    # <A HREF = "agora.cgi?page=Letters.html&cart_id=">
    #
    # In this case, it will see the cart_id= tag and
    # substitute in the correct and complete
    # "cart_id=some_number".

    if (   ( $form_data{'add_to_cart_button'} ) && ( $sc_shall_i_let_client_know_item_added =~ /yes/i ) )  {
        $item_ordered_message = $sc_item_ordered_msg_token;
    }

    $the_file = agorascript( $the_file, 'pre', "$page", __FILE__, __LINE__ );


    # add special header meta tags
    my $temp_head_info = $sc_standard_head_info . $sc_special_page_meta_tags;
    # Added the following new token to be used in all pages
    $the_file =~ s/\[\[head_info\]\]/$temp_head_info/i;

    # new tokens for responsive design templates
    $the_file =~ s/\[\[doc_type\]\]/$sc_doctype/i;
    $the_file =~ s/\[\[page_content\]\]/$sc_page_content/i;

    # Home Page tokens used to insert other tokens (nested tokens)
    $the_file =~ s/\[\[HomeZone1\]\]/$sc_template_zonehome1_tokens/;
    $the_file =~ s/\[\[HomeZone2\]\]/$sc_template_zonehome2_tokens/;

    # add more nested tokens or other primary tokens like those for ZoneHome
    codehook( 'the_file_script_and_substitute_top' );

    # template ZoneHome widgets - can be used on other pages too (technically)
    $the_file =~ s/\[\[jumbotron\]\]/$sc_template_zonehome{'jumbotron'}/;
    $the_file =~ s/\[\[HighlightedProducts\]\]/$sc_template_zonehome{'highlightedProducts'}/;
    $the_file =~ s/\[\[responsive8HeaderSections\]\]/$sc_template_zonehome{'responsive8HeaderSections'}/;
    $the_file =~ s/\[\[marketingRows1\]\]/$sc_template_zonehome{'marketingRows1'}/;
    $the_file =~ s/\[\[marketingRows2\]\]/$sc_template_zonehome{'marketingRows2'}/;
    $the_file =~ s/\[\[featurette\]\]/$sc_template_zonehome{'featurette'}/;
    $the_file =~ s/\[\[ourProductCatList12\]\]/$sc_template_zonehome{'ourProductCatList12'}/;
    $the_file =~ s/\[\[ourProductCatList16\]\]/$sc_template_zonehome{'ourProductCatList16'}/;
    $the_file =~ s/\[\[donationAmountSelectorWithUserDefined\]\]/$sc_template_zonehome{'donationAmountSelectorWithUserDefined'}/;

    $the_file =~ s/\[\[currencyCode\]\]/$store_currency_code/ig;
    $the_file =~ s/\[\[sc_money_symbol\]\]/$sc_money_symbol/ig;

    # only works on paymetn gateways with display total abilities.
    $the_file =~ s/\[\[verifyDisplayTotal\]\]/$displayTotal/ig;

    # codehook incase the top one does not give preferred precedence necessary for nested tokens, etc.
    codehook( 'the_file_script_and_substitute_middle' );

    $the_file =~ s/\[\[item_ordered_msg\]\]/$item_ordered_message/ig;
    if ( $sc_global_bot_tracker eq '1' ) {
        $the_file =~ s/cart_id=\[\[cart_id\]\]/cart_id=/g;
        $the_file =~ s/cart_id=//g;
        $the_file =~ s/\[\[cart_id\]\]//g;
    }
    else {
        $the_file =~ s/cart_id=\[\[cart_id\]\]/cart_id=/ig;
        $the_file =~ s/cart_id=/cart_id=$cart_id_for_html/ig;
        $the_file =~ s/\[\[cart_id\]\]/$cart_id_for_html/ig;
    }
    $the_file =~ s/\[\[page\]\]/$form_data{'page'}/ig;
    $the_file =~ s/\[\[cartlink\]\]/$form_data{'cartlink'}/ig;
    $the_file =~ s/\[\[date\]\]/$date/ig;
    $the_file =~ s/\[\[agoracgi_ver\]\]/$versions{'agora.cgi'}/ig;
    $the_file =~ s/\[\[URLofImages\]\]/$URL_of_images_directory/ig;
    $the_file =~ s/\[\[scriptURL\]\]/$sc_main_script_url/ig;
    $the_file =~ s/\[\[ScriptPostURL\]\]/$sc_main_script_post_url/ig;
    $the_file =~ s/\[\[sc_order_script_url\]\]/$sc_order_script_url/ig;
    $the_file =~ s/\[\[StepOneURL\]\]/$sc_stepone_order_script_url/ig;
    $the_file =~ s/\[\[href_fields\]\]/$href_fields/ig;
    $the_file =~ s/\[\[make_hidden_fields\]\]/$hidden_fields/ig;
    $the_file =~ s/\[\[ppinc\]\]/$form_data{'ppinc'}/ig;
    $the_file =~ s/\[\[maxp\]\]/$form_data{'maxp'}/ig;
    $the_file =~ s/\[\[product\]\]/$form_data{'product'}/ig;
    $the_file =~ s/\[\[p_id\]\]/$form_data{'p_id'}/ig;
    $the_file =~ s/\[\[keywords\]\]/$keywords/ig;
    $the_file =~ s/\[\[next\]\]/$form_data{'next'}/ig;
    $the_file =~ s/\[\[exact_match\]\]/$form_data{'exact_match'}/ig;
    $the_file =~ s/\[\[member\]\]/$form_data{'member'}/ig;
    $the_file =~ s/\[\[affiliate\]\]/$form_data{'affiliate'}/ig;
    $the_file =~ s/\[\[TemplateName\]\]/$sc_headerTemplateRoot/ig;
    $the_file =~ s/\[\[BaseURL\]\]/$sc_store_base_URL/g;
    $the_file =~ s/\[\[sslBaseURL\]\]/$sc_SSL_base_URL/g;
    $the_file =~ s/\[\[ButtonSetURL\]\]/$sc_buttonSetURL/g;
    $the_file =~ s/\[\[storeFullURL\]\]/$sc_store_url/ig;
    $the_file =~ s/\[\[agora_offline_submit_button_text\]\]/$agora_offline_submit_button_text/ig;

    while ( $the_file =~ /(\[\[eval)([^%]+)(\]\])/i ) {
        $arg   = $2;
        $myans = eval($arg);
        if ( $@ ) { $myans = "[[ $agora_eval_error01 $arg ]]"; }
        $the_file =~ s/(\[\[eval)([^%]+)(\]\])/$myans/i; #]
    }

    while ( $the_file =~ /\[\[ZZZ\]\]/ ) {
        $cart_id_for_html = $cart_id;
        $the_file =~ s/\[\[ZZZ\]\]/$cart_id_for_html/;
    }

    $the_file = agorascript( $the_file, 'post', "$page", __FILE__, __LINE__ );
    $the_file = agorascript( $the_file, '',     "$page", __FILE__, __LINE__ );

    # Very Last thing, load headers and footers
    # These routines already have substitutions, agorascript, etc, and
    # are stand-alones, so do not need to make any additional changes to them

    # normal operation - v5.9 and above
    while ( $the_file =~ /\[\[StoreHeader\]\]/i ) {
        $my_text = GetStoreHeader();
        $the_file =~ s/\[\[StoreHeader\]\]/$my_text/i;
    }
    while ( $the_file =~ /\[\[StoreFooter\]\]/i ) {
        $my_text = GetStoreFooter();
        $the_file =~ s/\[\[StoreFooter\]\]/$my_text/i;
    }
    while ( $the_file =~ /\[\[SecureStoreHeader\]\]/i ) {
        $my_text = GetSecureStoreHeader();
        $the_file =~ s/\[\[SecureStoreHeader\]\]/$my_text/i;
    }

    return $the_file;
}

#######################################################################
#
#######################################################################

sub script_and_substitute_footer {
    local ($footer)   = @_;
    local ( $offlineSecureURL ) = q{};

    $footer = agorascript($footer,'pre','sub modify_form_footer', __FILE__,__LINE__);
    $footer =~ s/\[\[URLofImages\]\]/$URL_of_images_directory/g;
    $footer =~ s/\[\[cart_id\]\]/$cart_id/g;
    $footer =~ s/\[\[sc_order_script_url\]\]/$sc_order_script_url/g;
    $footer =~ s/\[\[StepOneURL\]\]/$sc_stepone_order_script_url/ig;
    $footer =~ s/\[\[ButtonSetURL\]\]/$sc_buttonSetURL/ig;
    $footer =~ s/\[\[continueButton\]\]/$agora_cart_footer_cont_button_text/ig;
    $footer =~ s/\[\[checkoutButton\]\]/$agora_cart_footer_checkout_button_text/ig;
    $footer =~ s/\[\[homesite_link_url\]\]/$sc_display_cartlinksite_url/;
    $footer =~ s/\[\[empty_donation_button\]\]/$agora_cart_footer_empty/;
    if ( $sc_pre_calc_shipping_installed =~ /yes/i ) {
        codehook('precheckoutshipButton');
        $footer =~ s/\[\[precalcshipping\]\]/$sc_pre_calc_shipping_display/g;
    }
    else { $footer =~ s/\[\[precalcshipping\]\]//g; }
    $footer = agorascript($footer,'post','sub modify_form_footer', __FILE__,__LINE__);
    $footer = agorascript($footer,"",'sub modify_form_footer', __FILE__,__LINE__);

    return $footer;
}

#######################################################################
#                 prep_displayProductPage Subroutine
#######################################################################

sub prep_displayProductPage {
    local ($the_whole_page) = @_;
    local ( $keywords, $imageURL, $hidden_fields, $href_fields, $my_ppinc ) = q{};
    local ($myproduct, $suppress_qty_box) = q{};
    local ($qty_box_html, $qty)              = q{};
    local ( $xarg, $xarg1, $xarg2, $temp_prod_description ) = q{};
    local ($auto_opt_no) = 0;
    local ($inv) = q{};    # inventory
    my ($tempString) = q{};
    my $temp_formatted_price = q{};
    my $sp1 = 11;
    my $np1 = 12;
    my $wp1 = 13;
    my $inve1 = 14;

    if ( $sc_default_qty_to_display ) {
        $qty = $sc_default_qty_to_display;
    }
    $myproduct = $form_data{'product'};
    if ( $sc_convert_product_token_underlines ) {
        $myproduct =~ s/\-/$sc_convert_product_token_dashes/g;
        $myproduct =~ s/\_/$sc_convert_product_token_underlines/g;
    }
    $keywords = $form_data{'keywords'};    # for href, not <FORM>, fields
    $keywords =~ s/ /+/g;

    $href_fields      = make_href_fields();
    $hidden_fields    = make_hidden_fields();
    $cart_id_for_html = '[[ZZZ]]';

    # Need to load option file first, if it has agorascript then
    # we must be able to execute it
    $the_whole_page =~ s/%%optionFile%%/$display_fields[3]/ig;

    while ( $the_whole_page =~ /(%%Load_Option_File )([^%]+)(%%)/i ) {
        my ($option_location);
        my ($field) = q{};
        $option_location = $2;
        $option_location =~ s/ //g;

        $field = load_opt_file($option_location);
        $field = option_prep( $field, $option_location, $item_ids[0] );
        $the_whole_page =~ s/(%%Load_Option_File )([^%]+)(%%)/$field/i;
    }

    $the_whole_page =
      agorascript( $the_whole_page, 'pre', "$my_ppinc", __FILE__, __LINE__ );

    codehook('before_ppinc_token_substitution');

    # checks inventory levels using user defined userfield
    if ( $mc_mgr_plugins_enabled =~ /inventory_control/ ) {
        if ( $database_fields[ $db{$sc_db_index_for_inventory} ] > 0 ) {
            my $temp_sc_inventory_available_html = $sc_inventory_available_html;
            $inv = "$display_fields[4]";
            if ( $sc_show_inventory_status =~ /yes/i ) {
                $temp_sc_inventory_available_html =~ s/\[\[message\]\]/$sc_inventory_status_text $database_fields[$db{$sc_db_index_for_inventory}]/;
                $inv .= $temp_sc_inventory_available_html;
            }
        }
        elsif ( ( $database_fields[ $db{$sc_db_index_for_inventory} ] ne '' ) && ( $database_fields[ $db{$sc_db_index_for_inventory} ] <= 0 ) )  {
            $sc_inventory_out_of_stock_html =~ s/\[\[message\]\]/$sc_out_of_stock_message/;
            $inv = $sc_inventory_out_of_stock_html;
            $the_whole_page =~ s/%%QtyBox%%//ig;
            $the_whole_page =~ s/%%zeroQtyBox%%//ig;
            $the_whole_page =~ s/(%%QtyBox-)([^%]+)(%%)//ig;
            $the_whole_page =~ s/\[\[disableButton\]\]/ disabled\=\"disabled\" /g;
        }
    }    # end check inventory userfield

    $imageURL = $display_fields[0];
    $imageURL =~ s/\[\[URLofImages\]\]/$URL_of_images_directory/g;
    if ( $qty_box_html eq '' ) {
        $qty_box_html = $sc_default_qty_box_html;
    }
    if ($suppress_qty_box) {
        $the_whole_page =~ s/%%QtyBox%%/&nbsp;/ig;
        $the_whole_page =~ s/%%zeroQtyBox%%/&nbsp;/ig;
    }
    else {
        $the_whole_page =~ s/%%QtyBox%%/$qty_box_html/ig;
    }

    while ( $the_whole_page =~ /(%%QtyBox-)([^%]+)(%%)/i ) {
        my $arg = $2;

       # if the qty part is not specified (or not even a comma) then use default
        my ( $arg1, $arg2, $junk ) = split( /,/, $arg . ",$qty,", 3 );
        $arg1 =~ s/'//g;
        $arg1 =~ s/"//g;
        $arg2 =~ s/'//g;
        $arg2 =~ s/"//g;
        my $myans = QtyBox( $arg1, $arg2 );
        $the_whole_page =~ s/(%%QtyBox-)([^%]+)(%%)/$myans/i;
    }

    while ( $the_whole_page =~ /%%zeroQtyBox/i ) {
        $qty = q{};
        $the_whole_page =~ s/%%zeroQtyBox%%/$qty_box_html/ig;
    }

    while ( $the_whole_page =~ /(%%itemID-)([^%]+)(%%)/i ) {
        my $arg = $2;
        my ( $arg1, $arg2 ) = split( /,/, $arg, 2 );
        $arg1 =~ s/'//g;
        $arg1 =~ s/"//g;
        my $myans = itemID($arg1);
        $the_whole_page =~ s/(%%itemID-)([^%]+)(%%)/$myans/i;
    }

    while ( $the_whole_page =~ /(%%prodID-)([^%]+)(%%)/i ) {
        my $arg = $2;
        my ( $arg1, $arg2 ) = split( /,/, $arg, 2 );
        $arg1 =~ s/'//g;
        $arg1 =~ s/"//g;
        my $myans = prodID($arg1);
        $the_whole_page =~ s/(%%prodID-)([^%]+)(%%)/$myans/i;
    }

    # checks inventory levels using user defined userfield
    if ($sc_db_index_for_inventory) {
        $inv = "$display_fields[4]";
        my $temp_sc_inventory_available_html = $sc_inventory_available_html;
        if ( $database_fields[ $db{$sc_db_index_for_inventory} ] > 0 ) {
            if ( $sc_show_inventory_status =~ /yes/i ) {
                $temp_sc_inventory_available_html =~ s/\[\[message\]\]/$sc_inventory_status_text $database_fields[$db{$sc_db_index_for_inventory}]/;
                $inv .= $temp_sc_inventory_available_html;
            }
        }
        elsif ( ( $database_fields[ $db{$sc_db_index_for_inventory} ] ne '' ) && ( $database_fields[ $db{$sc_db_index_for_inventory} ] <= 0 ) )  {
            $sc_inventory_out_of_stock_html =~ s/\[\[message\]\]/$sc_out_of_stock_message/;
            $inv .= $sc_inventory_out_of_stock_html;
        }
    }    # end check inventory userfield

    #$temp_prod_description = $database_fields{'prod_description'}; # sql ?
    $temp_prod_description = $display_fields[2];
    $temp_prod_description = substr( $temp_prod_description, 0, $sc_max_product_description_chars );


    $temp_formatted_price = $display_fields[4];
    $temp_formatted_price =~s/\$//;
    $temp_formatted_price =~s/£//;
    $temp_formatted_price =~s/\&pound;//;
    $temp_formatted_price =~s/\&euro;//;
    $temp_formatted_price =~s/€//;

    # normal operation - v5.9 and above
    $the_whole_page =~ s/\[\[disableButton\]\]//g; # just in case still there
    $the_whole_page =~ s/\[\[image\]\]/$imageURL/ig;
    $the_whole_page =~ s/\[\[cartlink\]\]/$cartlink/ig;
    $the_whole_page =~ s/\[\[description_teaser\]\]/$temp_prod_description/ig;
    $the_whole_page =~ s/\[\[description\]\]/$display_fields[2]/ig;
    $the_whole_page =~ s/\[\[Qty\]\]/$qty/ig;
    $the_whole_page =~ s/\[\[userFieldOne\]\]/$display_fields[6]/ig;
    $the_whole_page =~ s/\[\[userFieldTwo\]\]/$display_fields[7]/ig;
    $the_whole_page =~ s/\[\[userFieldThree\]\]/$display_fields[8]/ig;
    $the_whole_page =~ s/\[\[userFieldFour\]\]/$display_fields[9]/ig;
    $the_whole_page =~ s/\[\[userFieldFive\]\]/$display_fields[10]/ig;
    if ( $sc_userfields_available =~ /10|20/ ) {
        $the_whole_page =~ s/\[\[userFieldSix\]\]/$display_fields[11]/ig;
        $the_whole_page =~ s/\[\[userFieldSeven\]\]/$display_fields[12]/ig;
        $the_whole_page =~ s/\[\[userFieldEight\]\]/$display_fields[13]/ig;
        $the_whole_page =~ s/\[\[userFieldNine\]\]/$display_fields[14]/ig;
        $the_whole_page =~ s/\[\[userFieldTen\]\]/$display_fields[15]/ig;
        $sp1 = 16;
        $np1 = 17;
        $wp1 = 18;
        $inve1 = 19;
    }
    if ( $sc_userfields_available eq '20' ) {
        $the_whole_page =~ s/\[\[userFieldEleven\]\]/$display_fields[16]/ig;
        $the_whole_page =~ s/\[\[userFieldTwelve\]\]/$display_fields[17]/ig;
        $the_whole_page =~ s/\[\[userFieldThirteen\]\]/$display_fields[18]/ig;
        $the_whole_page =~ s/\[\[userFieldFourteen\]\]/$display_fields[19]/ig;
        $the_whole_page =~ s/\[\[userFieldFifteen\]\]/$display_fields[20]/ig;
        $the_whole_page =~ s/\[\[userFieldSixteen\]\]/$display_fields[21]/ig;
        $the_whole_page =~ s/\[\[userFieldSeventeen\]\]/$display_fields[22]/ig;
        $the_whole_page =~ s/\[\[userFieldEighteen\]\]/$display_fields[23]/ig;
        $the_whole_page =~ s/\[\[userFieldNineteen\]\]/$display_fields[24]/ig;
        $the_whole_page =~ s/\[\[userFieldTwenty\]\]/$display_fields[25]/ig;
        $sp1 = 26;
        $np1 = 27;
        $wp1 = 28;
        $inve1 = 29;
    }
    $the_whole_page =~ s/\[\[scriptURL\]\]/$sc_main_script_url/ig;
    $the_whole_page =~ s/\[\[StepOneURL\]\]/$sc_stepone_order_script_url/ig;
    $the_whole_page =~ s/\[\[gateway_username\]\]/$sc_gateway_username/ig;

    if ( $sc_global_bot_tracker eq '1' ) {
        $the_whole_page =~ s/\[\[CartID\]\]//ig;
        $the_whole_page =~ s/cart_id=//g;
        $the_whole_page =~ s/\[\[cart_id\]\]//g;
    }
    else {
        $the_whole_page =~ s/\[\[CartID\]\]/$cart_id_for_html/ig;
        $the_whole_page =~ s/\[\[cart_id\]\]/$cart_id_for_html/ig;
    }

    $the_whole_page =~ s/\[\[make_hidden_fields\]\]/$hidden_fields/ig;
    $the_whole_page =~ s/\[\[ppinc\]\]/$form_data{'ppinc'}/ig;
    $the_whole_page =~ s/\[\[maxp\]\]/$form_data{'maxp'}/ig;
    $the_whole_page =~ s/\[\[page\]\]/$page/ig;
    $the_whole_page =~ s/\[\[p_id\]\]/$form_data{'p_id'}/ig;
    $the_whole_page =~ s/\[\[prod_db_id\]\]/$item_ids[0]/g;
    $the_whole_page =~ s/\[\[keywords\]\]/$keywords/ig;
    $the_whole_page =~ s/\[\[next\]\]/$form_data{'next'}/ig;

   # portable next/prev token inspired by Dan - CartSolutions.net - Sept 1, 2008
    if ( $sc_use_alt_next_display =~ /Yes/ ) {
        $the_whole_page =~ s/\[\[alt_next\]\]/$prod_message/ig;
    }

    $the_whole_page =~ s/\[\[exact_match\]\]/$form_data{'exact_match'}/ig;
    $the_whole_page =~ s/\[\[exact_case\]\]/$form_data{'exact_case'}/ig;
    $the_whole_page =~ s/\[\[form_user2\]\]/$form_data{'user2'}/ig;
    $the_whole_page =~ s/\[\[form_user3\]\]/$form_data{'user3'}/ig;
    $the_whole_page =~ s/\[\[form_user4\]\]/$form_data{'user4'}/ig;
    $the_whole_page =~ s/\[\[form_user5\]\]/$form_data{'user5'}/ig;
    if ( $sc_userfields_available =~ /10|20/ ) {
        $the_whole_page =~ s/\[\[form_user6\]\]/$form_data{'user6'}/ig;
        $the_whole_page =~ s/\[\[form_user7\]\]/$form_data{'user7'}/ig;
        $the_whole_page =~ s/\[\[form_user8\]\]/$form_data{'user8'}/ig;
        $the_whole_page =~ s/\[\[form_user9\]\]/$form_data{'user9'}/ig;
        $the_whole_page =~ s/\[\[form_user10\]\]/$form_data{'user10'}/ig;
    }
    if ( $sc_userfields_available eq '20' ) {
        $the_whole_page =~ s/\[\[form_user11\]\]/$form_data{'user11'}/ig;
        $the_whole_page =~ s/\[\[form_user12\]\]/$form_data{'user12'}/ig;
        $the_whole_page =~ s/\[\[form_user13\]\]/$form_data{'user13'}/ig;
        $the_whole_page =~ s/\[\[form_user14\]\]/$form_data{'user14'}/ig;
        $the_whole_page =~ s/\[\[form_user15\]\]/$form_data{'user15'}/ig;
        $the_whole_page =~ s/\[\[form_user16\]\]/$form_data{'user16'}/ig;
        $the_whole_page =~ s/\[\[form_user17\]\]/$form_data{'user17'}/ig;
        $the_whole_page =~ s/\[\[form_user18\]\]/$form_data{'user18'}/ig;
        $the_whole_page =~ s/\[\[form_user19\]\]/$form_data{'user19'}/ig;
        $the_whole_page =~ s/\[\[form_user20\]\]/$form_data{'user20'}/ig;
    }
    $the_whole_page =~ s/\[\[href_fields\]\]/$href_fields/ig;
    $the_whole_page =~ s/\[\[image\]\]/$imageURL/ig;
    $the_whole_page =~ s/\[\[viewcart\]\]/$agora_productPage_viewcart_link/ig;
    $the_whole_page =~ s/\[\[checkout\]\]/$agora_productPage_checkout_link/ig;
    $the_whole_page =~ s/\[\[restartcheckout\]\]/$agora_productPage_restartcheckout_link/ig;
    $the_whole_page =~ s/\[\[largerimagelinktext\]\]/$agora_productPage_largerimage_link/ig;


    $the_whole_page =~ s/\[\[seemoreButtonText\]\]/$agora_productPage_seemore_button_text/ig;
    $the_whole_page =~ s/\[\[seemoreButtonName\]\]/$agora_productPage_seemore_button_name/ig;
    $the_whole_page =~ s/\[\[addToCartButtonText\]\]/$agora_productPage_addtocart_button_text/ig;
    $the_whole_page =~ s/\[\[closeModalText\]\]/$agora_productPage_close_modal_text/ig;
    $the_whole_page =~ s/\[\[showThisProduct\]\]/$agora_productPage_search_display_me_text/ig;
    $the_whole_page =~ s/\[\[showSimilarLinkText\]\]/$agora_productPage_search_show_similar_text/ig;

    if ( $mc_mgr_plugins_enabled =~ /inventory_control/ ) {
        $the_whole_page =~ s/\[\[price\]\]/$inv/ig;
    }
    else {
        $the_whole_page =~ s/\[\[price\]\]/$display_fields[4]/ig;
    }
    $the_whole_page =~ s/\[\[price_raw\]\]/$temp_formatted_price/ig;
    $the_whole_page =~ s/\[\[currencyCode\]\]/$store_currency_code/ig;
    $the_whole_page =~ s/\[\[cost\]\]/$item_ids[2]/ig;
    $the_whole_page =~ s/\[\[shipping\]\]/$display_fields[5]/ig;
    $the_whole_page =~ s/\[\[SpecialsPrice\]\]/$display_fields[$sp1]/ig;
    $the_whole_page =~ s/\[\[NetProfit\]\]/$display_fields[$np1]/ig;
    $the_whole_page =~ s/\[\[WholesalePrice\]\]/$display_fields[$wp1]/ig;
    $the_whole_page =~ s/\[\[Inventory\]\]/$display_fields[$inve1]/ig;
    $the_whole_page =~ s/%%itemID%%/item-$itemID/ig;
    $the_whole_page =~ s/%%ProductID%%/$item_ids[0]/ig;
    $the_whole_page =~ s/\[\[ProductID\]\]/$item_ids[0]/ig;
    $the_whole_page =~ s/\[\[img_pid\]\]/$item_ids[0]/ig;
    $the_whole_page =~ s/\[\[CategoryID\]\]/$item_ids[1]/ig;
    $the_whole_page =~ s/\[\[URLofImages\]\]/$URL_of_images_directory/ig;
    $the_whole_page =~ s/\[\[TemplateName\]\]/$sc_headerTemplateRoot/ig;
    $the_whole_page =~ s/\[\[BaseURL\]\]/$sc_store_base_URL/ig;
    $the_whole_page =~ s/\[\[sslBaseURL\]\]/$sc_SSL_base_URL/ig;
    $the_whole_page =~ s/\[\[sc_money_symbol\]\]/$sc_money_symbol/ig;
    $the_whole_page =~ s/\[\[product\]\]/$myproduct/ig;
    $the_whole_page =~ s/\[\[name\]\]/$display_fields[1]/ig;
    $the_whole_page =~ s/\[\[storeFullURL\]\]/$sc_store_url/ig;
    if ( $sc_catlev2 && $form_data{"$sc_catlev2"} ) {
        $the_whole_page =~ s/\[\[subcatlvl2\]\]/&amp;$sc_catlev2=$form_data{"$sc_catlev2"}/ig;
    } else {
        $the_whole_page =~ s/\[\[subcatlvl2\]\]//ig;
    }

    if ( $sc_catlev3 && $form_data{"$sc_catlev3"} ) {
        $the_whole_page =~ s/\[\[subcatlvl3\]\]/&amp;$sc_catlev3=$form_data{"$sc_catlev3"}/ig;
    } else {
        $the_whole_page =~ s/\[\[subcatlvl3\]\]//ig;
    }

    while ( $the_whole_page =~ /\[\[ZZZ\]\]/ ) {
        $the_whole_page =~ s/\[\[ZZZ\]\]/$cart_id/;
    }

    # Do this before the evals
    while ( $the_whole_page =~ /\[\[AutoOptionNo\]\]/i ) {
        $auto_opt_no = $auto_opt_no + 1;
        if ( $auto_opt_no < 100 ) { $auto_opt_no = "0$auto_opt_no"; }
        if ( $auto_opt_no < 10 )  { $auto_opt_no = "0$auto_opt_no"; }
        $the_whole_page =~ s/\[\[AutoOptionNo\]\]/$auto_opt_no/i;
    }

    $the_whole_page = agorascript( $the_whole_page, 'autoopt', "$my_ppinc", __FILE__, __LINE__ );

    while ( $the_whole_page =~ /(\[\[eval)([^%]+)(\]\])/i ) {
        $arg   = $2;
        $myans = eval($arg);
        if ( $@ ne "" ) { $myans = "[[ $agora_eval_error01 $arg ]]"; }
        $the_whole_page =~ s/(\[\[eval)([^%]+)(\]\])/$myans/i;
    }

    codehook('after_ppinc_token_substitution');

    $the_whole_page =  agorascript( $the_whole_page, 'post', "$my_ppinc", __FILE__, __LINE__ );

    return $the_whole_page;

}

#######################################################################

1;
