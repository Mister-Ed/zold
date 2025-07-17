$versions{'cart.pl'} = '06.6.00.0000';

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
# Handles outputs of cart order totals shown at display cart and
# display order form screens. Includes:
#
#       subtotals
#       discounts
#       sales taxes
#       shipping fees
#       grand totals
#
#


#######################################################################
#                    print_order_totals Subroutine
#######################################################################

sub print_order_totals {

    local ($continue) = 1;
    local $cart_totals_table_class = 'ac_totals_table_ctr';
    if ( $reason_to_display_cart ) {
        $cart_totals_table_class = 'ac_totals_table_ctr_nopull';
    }

    codehook('print_order_totals_top');

    if ( $skip_cart_totals_table && $sc_donation_mode eq 'yes' ) {
        &alternate_order_totals();
    }

    if ( $continue == 0 ) { return; }
    print qq~<div class="checkout_container"><div class="$cart_totals_table_class">
<table class="ac_totals_table" cellspacing="0">
<tr>
<th colspan="2">$sc_totals_table_thdr_label</th>
</tr>
<tr>
<td class="ac_totals_table_itot">${sc_totals_table_itot_label}:</td>
<td class="ac_totals_table_itotp">$price</td>
</tr>
~;

    if ( $form_data{'dc'} || $form_data{'display_cart'} ||  $form_data{'submit_deletion_button.x'} || $form_data{'submit_change_quantity_button.x'} || ( $are_we_before_or_at_process_form =~ /before/i ) ) {
        if ( $sc_totals_table_estimated_ship_label eq '' ) {
             $sc_totals_table_estimated_ship_label = 'Approx. Shipping';
        }
        if ( $sc_totals_table_estimated_disc_label eq '' ) {
             $sc_totals_table_estimated_disc_label = 'Approx. Discount';
        }
        $sc_totals_table_ship_label = $sc_totals_table_estimated_ship_label;
        $sc_totals_table_disc_label = $sc_totals_table_estimated_disc_label;
    }

    if ( ( $zfinal_shipping > 0 ) && ( $sc_show_shipping_label_box =~ /yes/i ) )   {
        $val = format_price($zfinal_shipping);


        print qq~<tr>
<td class="ac_totals_table_ship">$sc_totals_table_ship_label</td>
<td class="ac_totals_table_shipp">$val</td>
</tr>
~;
    }

    # show free shipping if enabled
    elsif ( ( $zfinal_shipping eq 0 ) && ( $sc_show_shipping_label_box =~ /yes/i ) && ( $sc_show_shipping_box_at_zero =~ /yes/i ) && ( $are_we_before_or_at_process_form !~ /before/i ) )   {
        if ( $sc_totals_table_free_shipping_text_displayed eq '' ) {
            $sc_totals_table_free_shipping_text_displayed = 'FREE';
        }
        print qq~<tr>
<td class="ac_totals_table_ship">$sc_totals_table_ship_label</td>
<td class="ac_totals_table_shipp">$sc_totals_table_free_shipping_text_displayed</td>
</tr>
~;
    }
    if ( $zfinal_discount > 0 ) {
        $val = format_price($zfinal_discount);
        print qq~<tr>
<td class="ac_totals_table_disc">$sc_totals_table_disc_label</td>
<td class="ac_totals_table_discp">$val</td>
</tr>
~;
    }
    if ( $zfinal_sales_tax > 0 ) {
        $val = format_price($zfinal_sales_tax);
        # Canadian GST tax
        if ( ( $sc_sales_tax_state =~ /^Canada$/i ) && ( $form_data{'Ecom_ShipTo_Postal_StateProv'} =~ /^NT$|^NWT$|^NU$|^YT$|^YK$|^AB$|^MB$|^SK$|^QC$|^PQ$|^PEI$|^PE$/ ) ) {
            print qq~
<td class="ac_totals_table_stax">$sc_totals_table_GSTtax_label</td>
<td class="ac_totals_table_staxp">$val</td>
~;
        }
        else {
            print qq~
            <tr>
<td class="ac_totals_table_stax">$sc_totals_table_stax_label</td>
<td class="ac_totals_table_staxp">$val</td>
</tr>
~;
        }
    }

    if ( ( $zfinal_PSTsales_tax > 0 ) && ( $sc_sales_tax_state eq 'Canada' ) ) {
        $val = format_price($zfinal_PSTsales_tax);
        print qq~<tr>
<td class="ac_totals_table_stax">$sc_totals_table_PSTtax_label</td>
<td class="ac_totals_table_staxp">$val</td>
</tr>
~;
    }
    if ( $zfinal_extra_tax1 > 0 ) {
        $val = format_price($zfinal_extra_tax1);
        print qq~<tr>
<td class="ac_totals_table_tax1">$sc_extra_tax1_name</td>
<td class="ac_totals_table_tax1p">$val</td>
</tr>
~;
    }
    if ( $zfinal_extra_tax2 > 0 ) {
        $val = format_price($zfinal_extra_tax2);
        print qq~<tr>
<td class="ac_totals_table_tax2">$sc_extra_tax2_name</td>
<td class="ac_totals_table_tax2p">$val</td>
</tr>
~;
    }
    if ( $zfinal_extra_tax3 > 0 ) {
        $val = format_price($zfinal_extra_tax3);
        print qq~<tr>
<td class="ac_totals_table_tax3">$sc_extra_tax3_name</td>
<td class="ac_totals_table_tax3p">$val</td>
</tr>
~;
    }

    # buySafe
    if (   ( $sc_buySafe_is_enabled =~ /$sc_yes/ )
        && ( $zfinal_buySafe > 0 )
        && ( $zsubtotal > 0 ) )
    {
        if ( $sc_buySafe_bond_fee_mini_display_text eq '' ) {
            $sc_buySafe_bond_fee_mini_display_text = 'buySafe Bond :';
        }
        $val = format_price($zfinal_buySafe);
        print qq~<tr>
<td class="ac_totals_table_buysa">$sc_buySafe_bond_fee_mini_display_text</td>
<td class="ac_totals_table_buysap">$val</td>
</tr>
~;
    }

    print qq~$sc_totals_table_line_image~;

    if (   ( $sc_show_subtotal_label_box =~ /yes/i )
        && ( $are_we_before_or_at_process_form =~ /at/i ) )
    {
        print qq~<tr>
<td class="ac_totals_table_tot">$sc_totals_table_gtot_label</td>
<td class="ac_totals_table_totp">$grand_total</td>

~;
    }
    else {
        print qq~<tr>
<td class="ac_totals_table_tot">$sc_totals_table_subtot_label</td>
<td class="ac_totals_table_totp">$grand_total</td>
~;
    }
    print qq~
</tr>
</table>
~;

    # buysafe bonding button display, if successful and enabled
    if (   ( $sc_buySafe_is_enabled =~ /yes/ )
        && ( $sc_processing_order ne 'yes' )
        && ( $sc_buySafe_bonding_signal !~ /HASH\(/i )
        && ( $zsubtotal > 0 ) )
    {
        my @buysafearraythingy = split( /\&/, $sc_buySafe_bonding_signal, 6 );
        my ( $junk, $temp_buysafe_thingy ) =
          split( /=/, $buysafearraythingy[4] );

        # debug
        if ( $sc_buysafe_debug_req_and_response =~ /yes/i ) {
            print qq|<br><br>\$junk = $junk<br><br>
 \$temp_buysafe_thingy = $temp_buysafe_thingy<br><br>
 |;
        }

        my $buySafe_page_url = q{};

        if ( form_check('display_cart') ) {
            $buySafe_page_url = '&dc=1';
        }
        elsif ( form_check('dc') ) {
            $buySafe_page_url = '&dc=1';
        }
        elsif ( form_check('order_form_button') ) {
            $buySafe_page_url = '&order_form_button.x=1';
        }

        if ( $temp_buysafe_thingy eq '' ) {
            $temp_buysafe_thingy = 'False';
        }

        if (   ( $temp_buysafe_thingy eq 'True' )
            && ( $sc_buySafe_customer_desires_bond )
            && ( $sc_buySafe_customer_desires_bond eq 'true' ) )
        {    # print buysafe bond flash button

            print qq|
<input type="hidden" name="removebuysafebond" value="true">
<input type="hidden" name="buySAFE" value="true">|;
            print $sc_buySafe_bonding_signal;

            if ( $sc_buySafe_bond_call_success =~ /true/i ) {
                print qq|<div class="buysafe"><a href="$sc_buySafe_cart_details_URL" target="new">$sc_buySafe_cart_details_text</a></div>
|;
            }
        }
        else {    # print add new buysafe bond button
            print qq|<input type="hidden" name="addbuysafebond" value="true">
<input type="hidden" name="buySAFE" value="false">
$sc_buySafe_bonding_signal
|;
            if ( $sc_buySafe_bond_call_success =~ /true/i ) {
                print qq|<div class="buysafe"><a href="$sc_buySafe_cart_details_URL" target="new">$sc_buySafe_cart_details_text</a></div>
|;
            }
        }    #end of if/else on
    }    #end of buysafe bonding signal button display

    print qq~</div>~;
}

#######################################################################

#######################################################################
#                    alternate_order_totals Subroutine
#######################################################################

sub alternate_order_totals {

    local ($continue2) = 1;

    codehook('alternate_order_totals_top');

    if ( $continue2 == 0 ) { return; }

    # fill in with modification from print_order_totals

}

#######################################################################

1;
