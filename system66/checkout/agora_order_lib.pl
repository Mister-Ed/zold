$versions{'agora_order_lib.pl'} = '06.6.00.0006';

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

require_supporting_libraries( __FILE__, __LINE__, "$sc_mail_lib_path", "$sc_ship_lib_path" );
codehook( 'order_library_init' );

#
# This library contains code for displaying/modifying the cart
# as well as processing the order.  This lib is only loaded
# upon demand.
#
#

########################################################################
#                  eform_check Subroutine
########################################################################

sub eform_check {
    my ( $field, $val, $returnv ) = @_;
    if ( $eform{$field} eq $val ) { return $returnv; }
    return '';
}

########################################################################
#                  gateway_form_field_check Subroutine
########################################################################
#
# Payment gateway agnostic.
# Checks form fields submitted from step one (order form display).
# Makes sure "ShipTo" fields are populated cart side if only billing
# information is filled in.
#
########################################################################

sub gateway_form_field_check {

    if ( $form_data{'Ecom_ShipTo_Postal_Name_Last'} eq '' ) {
        if ( $form_data{'Ecom_BillTo_Postal_Name_Last'} ) {
            $form_data{'Ecom_ShipTo_Postal_Name_Last'} = $form_data{'Ecom_BillTo_Postal_Name_Last'};
        }
    }

    if ( $form_data{'Ecom_ShipTo_Postal_Name_First'} eq '' ) {
        if ( $form_data{'Ecom_BillTo_Postal_Name_First'} ) {
            $form_data{'Ecom_ShipTo_Postal_Name_First'} = $form_data{'Ecom_BillTo_Postal_Name_First'};
        }
    }

    if ( $form_data{'Ecom_ShipTo_Company_Name'} eq '' ) {
        if ( $form_data{'Ecom_BillTo_Company_Name'} ) {
            $form_data{'Ecom_ShipTo_Company_Name'} = $form_data{'Ecom_BillTo_Company_Name'};
        }
    }

    if ( $form_data{'Ecom_ShipTo_Postal_Street_Line1'} eq '' ) {
        if ( $form_data{'Ecom_BillTo_Postal_Street_Line1'} ) {
            $form_data{'Ecom_ShipTo_Postal_Street_Line1'} = $form_data{'Ecom_BillTo_Postal_Street_Line1'};
            $form_data{'Ecom_ShipTo_Postal_Street_Line2'} = $form_data{'Ecom_BillTo_Postal_Street_Line2'};
            $form_data{'Ecom_ShipTo_Postal_Street_Line3'} = $form_data{'Ecom_BillTo_Postal_Street_Line3'};
        }
    }

    if ( $form_data{'Ecom_ShipTo_Postal_City'} eq '' ) {
        if ( $form_data{'Ecom_BillTo_Postal_City'} ) {
            $form_data{'Ecom_ShipTo_Postal_City'} = $form_data{'Ecom_BillTo_Postal_City'};
        }
    }

    if ( $form_data{'Ecom_ShipTo_Postal_StateProv'} eq '' ) {
        if ( $form_data{'Ecom_BillTo_Postal_StateProv'} ) {
            $form_data{'Ecom_ShipTo_Postal_StateProv'} = $form_data{'Ecom_BillTo_Postal_StateProv'};
        }
    }

     if ( $form_data{'Ecom_ShipTo_Postal_PostalCode'} eq '' ) {
        if ( $form_data{'Ecom_BillTo_Postal_PostalCode'} ) {
            $form_data{'Ecom_ShipTo_Postal_PostalCode'} = $form_data{'Ecom_BillTo_Postal_PostalCode'};
        }
    }

    if ( $form_data{'Ecom_ShipTo_Postal_CountryCode'} eq '' ) {
        if ( $form_data{'Ecom_BillTo_Postal_CountryCode'} ) {
            $form_data{'Ecom_ShipTo_Postal_CountryCode'} = $form_data{'Ecom_BillTo_Postal_CountryCode'};
        }
    }

}

########################################################################
#                  calculate_final_values Subroutine
########################################################################
#
# subroutine: calculate_final_values
#   Usage:
#         ($final_shipping,
#          $final_discount,
#          $final_sales_tax,$grand_total) =
#    calculate_final_values($subtotal,
#                       $total_quantity,
#                       $total_measured_quantity,
#                       $are_we_before_or_at_process_form);
#
#   Parameters:
#     $subtotal = the current cart subtotal
#     $totalquantity = the total quantity of items in
#        in the cart
#     $total_measured_quantity = the total quantity
#        of whatever field you want to measure in the
#        the cart (as specified in the setup file)
#     $are_we_before_or_at_process_form = values
#       ("before" or "at") -- This indicates which
#       calculations to support based on the setup
#       file
#
#   Output:
#     $final_shipping = final value of shipping
#     $final_discount = final value of discount
#     $final_sales_tax = final sales tax
#     $grand_total = new grand total now that the
#       above items have been calculated
#
#  Taxable shipping and discount deductions corrected
#
########################################################################

sub calculate_final_values {
    local ( $taxable_grand_total, $subtotal, $total_quantity,
        $total_measured_quantity, $are_we_before_or_at_process_form, $api_call_status )
      = @_;
    local ( @testlines, $junk1, $junk2 ) = q{};
    local ( $mypass, $save1, $save2, $save3, $save4, $save5,  $save6, $save7, $save8 ) = q{};
    local ( $final_shipping, $final_discount ) = 0;
    local ( $final_sales_tax,  $final_extra_tax1 ) = 0;
    local ( $final_extra_tax2, $final_extra_tax3 ) = 0;
    local ( $final_buySafe, $calc_loop, $grand_total )   = 0;
    local ( $final_PST_tax )   = 0;
    $temp_total = $subtotal;
    local $temp_taxable_total = $taxable_grand_total;

    # We got through THREE cycles of
    # calculation. Why? Because we have
    # THREE things to calculate:
    #
    #  shipping
    #  discount
    #  sales tax
    # agora.cgi note: actually, we kept the three cycles, but have
    # added 3 additional (and optional) calculations:
    # extra_tax1, extra_tax2, extra_tax3
    #
    # The simplest thing is to calculate
    # all of these at once on the subtotal.
    #
    # However, your logic may not work that way.
    #
    # You may want one or more of these calculations
    # calculated and applied to the subtotal before
    # another calculation so that the next calculation
    # is based off of a larger subtotal amount.
    #
    # Thus, in the setup file there are variables
    # that you can set for the above calculations to
    # let the system know which order you want to use
    # in calculating the values.
    my $max_loops = 3;

    codehook('before_final_values_loop');

    for ( 1 .. $max_loops ) {

        # At the beginning of the loop, we
        # set the calculated values to 0.
        $shipping   = 0;
        $discount   = 0;
        $sales_tax  = 0;
        $sales_PSTtax = 0;
        $extra_tax1 = 0;
        $extra_tax2 = 0;
        $extra_tax3 = 0;
        $calc_loop  = $_;

        codehook('begin_final_values_loop_iteration');

        # The calculation logic may also
        # be different depending on whether we
        # are at the actual form where the
        # order is being processed.
        #
        # OR
        #
        # Whether we are at the form that
        # the user needs to enter data into
        # (such as state or shipping type).
        #
        # For example, you may not be able
        # to provide the user an estimate of sales
        # tax until you learn what state they are
        # in. So you should only calculate this
        # value at the process order form instead of
        # the initial display of the order form.

        if ( $are_we_before_or_at_process_form =~ /before/i ) {

            # Each of the items is calculated

            if ( $sc_calculate_discount_at_display_form == $calc_loop ) {
                $discount = calculate_discount( $temp_total, $total_quantity,$total_measured_quantity, $are_we_before_or_at_process_form );
				codehook( 'calculate_final_values_calc_discount_display_form' );
                if ( ( $sc_calculate_sales_tax_at_process_form >= $calc_loop ) && ( $sc_tax_before_discounts !~ /yes/i ) ) {
                    $temp_taxable_total -= $discount;
                }
            }    # End of if discount gets calculated here

            if ( ( $sc_calculate_shipping_at_display_form == $calc_loop )
                 # next line allows shipping logic to be calculated at display cart and order form display
                 || ( ( $sc_verify_shipto_method ne '' ) && ( $sc_verify_shipping > 0 ) && ( $sc_verify_shipping_thing ne '' ) && ( $sc_shipping_orderform_prevent_thingy < 1 ) )
                 ) {
                codehook('calculate_final_values_calc_shipping_display_form_top');
                $sc_shipping_orderform_prevent_thingy = 1; # prevent orderform display from calculating shipping logic more than once, all others were okay previously
                $shipping = define_shipping_logic( $total_measured_quantity,$stevo_shipping_thing );
                if ( ( $sc_calculate_sales_tax_at_process_form > $calc_loop ) && ( $sc_calculate_shipping_at_display_form == $calc_loop ) ) {
                    $temp_taxable_total += $shipping;
                }
                codehook('calculate_final_values_calc_shipping_display_form_bottom');
            }   # End of shipping calculations

            if ( $sc_calculate_sales_tax_at_display_form == $calc_loop ) {
                $sales_tax = calculate_sales_tax($temp_taxable_total);
            }    # End of sales tax calculations

            if ( ( $sc_calculate_PSTsales_tax_at_display_form == $calc_loop ) && ( $sc_sales_tax_state eq 'Canada' ) ) {
                $sales_PSTtax = calculate_PSTsales_tax($temp_taxable_total);
            }    # End of PST sales tax calculations

            if ( $sc_calculate_extra_tax1_at_display_form == $calc_loop ) {
                $extra_tax1 = calculate_extra_tax1($temp_taxable_total);
            }    # End of extra tax1 calculations

            if ( $sc_calculate_extra_tax2_at_display_form == $calc_loop ) {
                $extra_tax2 = calculate_extra_tax2($temp_taxable_total);
            }    # End of extra tax2 calculations

            if ( $sc_calculate_extra_tax3_at_display_form == $calc_loop ) {
                $extra_tax3 = calculate_extra_tax3($temp_taxable_total);
            }    # End of extra tax3 calculations

            # The else handles the case of
            # whether we are at the process order
            # form
        }
        else {

            if ( $sc_calculate_discount_at_process_form == $calc_loop ) {
                $discount =  calculate_discount( $temp_total, $total_quantity, $total_measured_quantity );
				codehook( 'calculate_final_values_calc_discount_process_form' );
                if ( ( $sc_calculate_sales_tax_at_process_form >= $calc_loop ) && ( $sc_tax_before_discounts !~ /yes/i ) ) {
                    $temp_taxable_total -= $discount;
                }
            }    # End of if discount gets calculated here

            if ( $sc_calculate_shipping_at_process_form == $calc_loop ) {
                codehook( 'calculate_final_values_calc_shipping_process_form_top' );
                $shipping = define_shipping_logic( $total_measured_quantity, $stevo_shipping_thing );
                if ( $sc_calculate_sales_tax_at_process_form > $calc_loop ) {
                    $temp_taxable_total += $shipping;
                }
                codehook( 'calculate_final_values_calc_shipping_process_form_bottom' );
            }    # End of shipping calculations

            if ( $sc_calculate_sales_tax_at_process_form == $calc_loop ) {
                $sales_tax = calculate_sales_tax($temp_taxable_total);
            }    # End of sales tax calculations

            if ( ( $sc_calculate_PSTsales_tax_at_process_form == $calc_loop ) && ( $sc_sales_tax_state eq 'Canada' ) ) {
                $sales_PSTtax = calculate_PSTsales_tax($temp_taxable_total);
            }    # End of PST sales tax calculations

            if ( $sc_calculate_extra_tax1_at_process_form == $calc_loop ) {
                $extra_tax1 = calculate_extra_tax1($temp_taxable_total);
            }

            if ( $sc_calculate_extra_tax2_at_process_form == $calc_loop ) {
                $extra_tax2 = calculate_extra_tax2($temp_taxable_total);
            }

            if ( $sc_calculate_extra_tax3_at_process_form == $calc_loop ) {
                $extra_tax3 = calculate_extra_tax3($temp_taxable_total);
            }

        }    # End of if we are before or at process order form

        # Finally, for THIS CYCLE ONLY, we
        # calculate the new temp_total.
        #
        # We also assign the final discount
        # shipping, and sales tax values because
        # they might not be calculated again
        # in the next cycle.

        #lil pet peave
        if ( !( $total_quantity > 0 ) ) { $shipping = 0; }

        codehook('end_final_values_loop_iteration_before_calc');

        $final_discount   = $discount   if ( $discount > 0 );
        $final_shipping   = $shipping   if ( $shipping > 0 );
        $final_sales_tax  = $sales_tax  if ( $sales_tax > 0 );
        $final_extra_tax1 = $extra_tax1 if ( $extra_tax1 > 0 );
        $final_extra_tax2 = $extra_tax2 if ( $extra_tax2 > 0 );
        $final_extra_tax3 = $extra_tax3 if ( $extra_tax3 > 0 );
        $final_PST_tax = $sales_PSTtax if ( $sales_PSTtax > 0 );

        codehook('end_final_values_loop_iteration_after_calc');

    }    # End of $calc_loop

    $temp_total =
          $temp_total -
          $final_discount +
          $final_shipping +
          $final_sales_tax +
          $final_extra_tax1 +
          $final_extra_tax2 +
          $final_extra_tax3 +
          $final_PST_tax;

    # add in buySafe
    $final_buySafe = $sc_buySafe_bond_fee
      if ( ( $sc_buySafe_bond_fee > 0 ) && ( $subtotal > 0 ) );

    if ( ( $sc_buySafe_is_enabled =~ /yes/ ) && ( $subtotal > 0 ) ) {
        $temp_total += $final_buySafe;
    }

    # The grand total becomes the final temp
    # total after the routine has been processed
    $grand_total = $temp_total;

    # We return the main values that we calculated
    if ( $sc_verify_inv_no eq '' ) {

        # See if there is an old number in the verify file
        open( MYFILE, "$sc_verify_order_path" );
        @testlines = <MYFILE>;
        close(MYFILE);
        @testlines = grep( /sc_verify_inv_no/, @testlines );
        ( $junk1, $sc_verify_inv_no, $junk2 ) = split( /\"/, @testlines[0], 3 );
    }

    if ( $sc_verify_inv_no ) {
        $current_verify_inv_no = $sc_verify_inv_no;
    }
    else {
        $current_verify_inv_no = generate_invoice_number();
    }
    $zz_shipping_thing = $sc_shipping_thing;
    $zz_shipping_thing =~ s/\|/\" . \n  \"\|/g;

    codehook('calculate_final_values_calc_save_verify_file_top');

    if (
        ( $sc_test_repeat == 0 )
        && (   ( $form_data{'submit_order_form_button'} )
            || ( $form_data{'submit_order_form_button.x'} ) )
      )
    {
        if ( $sc_global_bot_tracker ne '1' ) {
            codehook('api_insert_point_save_verify_file_top');
        }
        open( MYFILE, ">$sc_verify_order_path" ) || file_open_error( "$sc_verify_order_path", 'Order Form Verify File Error', __FILE__, __LINE__ );
        print MYFILE "#\n#These Values were calculated for the order:\n";
        print MYFILE "\$sc_verify_ip_addr = \"$ENV{'REMOTE_ADDR'}\";\n";
        print MYFILE "\$sc_verify_shipping = ", ( 0 + $final_shipping ), ";\n";
        print MYFILE "\$sc_verify_shipping_zip = \"", $form_data{'Ecom_ShipTo_Postal_PostalCode'}, "\";\n";
        print MYFILE "\$sc_verify_shipping_thing = \"",
          $zz_shipping_thing, "\";\n";
        print MYFILE "\$sc_verify_shipto_postal_stateprov = \"",
          $form_data{'Ecom_ShipTo_Postal_StateProv'}, "\";\n";
        print MYFILE "\$sc_verify_shipto_method = \"",
          $form_data{'Ecom_ShipTo_Method'}, "\";\n";
        print MYFILE "\$sc_verify_discount = ", ( 0 + $final_discount ),  ";\n";
        print MYFILE "\$sc_verify_tax = ",      ( 0 + $final_sales_tax ), ";\n";
        print MYFILE "\$sc_verify_PSTtax = ", ( 0 + $final_PST_tax ), ";\n";
        print MYFILE "\$sc_verify_etax1 = ", ( 0 + $final_extra_tax1 ), ";\n";
        print MYFILE "\$sc_verify_etax2 = ", ( 0 + $final_extra_tax2 ), ";\n";
        print MYFILE "\$sc_verify_etax3 = ", ( 0 + $final_extra_tax3 ), ";\n";
        print MYFILE "\$sc_verify_subtotal = ", ( 0 + $subtotal ), ";\n";

        if ( $sc_buySafe_is_enabled =~ /yes/ ) {
            print MYFILE "\$sc_verify_buySafe = ", ( 0 + $final_buySafe ),
              ";\n";
            print MYFILE "\$sc_verify_buySafe_display_text = \"$sc_buySafe_bond_fee_display_text\";\n";
            print MYFILE "\$sc_verify_buySafe_customer_desires_bond = \"$sc_buySafe_customer_desires_bond\";\n";
            print MYFILE "\$sc_buySafe_customer_desires_bond = \"$sc_buySafe_customer_desires_bond\";\n";
            print MYFILE "\$sc_buySafe_bond_fee_display_text = \"$sc_buySafe_bond_fee_display_text\";\n";
            print MYFILE "\$sc_buySafe_bonding_signal = qq|$sc_buySafe_bonding_signal|;\n";
            print MYFILE "\$sc_buySafe_bond_fee_mini_display_text = \"$sc_buySafe_bond_fee_mini_display_text\";\n";
        }
        print MYFILE "\$sc_verify_grand_total = ", ( 0 + $grand_total ), ";\n";
        print MYFILE "\$sc_verify_boxes_max_wt = \"", $sc_verify_boxes_max_wt, "\";\n";
        print MYFILE "\$sc_verify_Origin_ZIP = \"", $sc_verify_Origin_ZIP,  "\";\n";
        print MYFILE "\$sc_verify_inv_no = \"", $current_verify_inv_no, "\";\n";
        print MYFILE "\$sc_verify_paid_by_ccard = \"", $sc_paid_by_ccard, "\";\n";

        codehook('calculate_final_values_calc_save_verify_file_section_one');

        $mypass = make_random_chars();
        $mypass .= make_random_chars();
        $mypass .= make_random_chars();
        $mypass .= make_random_chars();
        $sc_pass_used_to_scramble = $mypass;

        if ( $sc_test_repeat ne 0 ) {

        # for security need to blank out these vars, since this is a page reload
            $form_data{'Ecom_Payment_Card_Number'}      = q{};
            $form_data{'Ecom_Payment_BankAcct_Number'}  = q{};
            $form_data{'Ecom_Payment_BankRoute_Number'} = q{};
            $form_data{'Ecom_Payment_Bank_Name'}        = q{};
            $form_data{'Ecom_Payment_Orig_Card_Number'} = q{};
        }

        # scramble and save vars, make sure we should have them at all!
        if ( $sc_scramble_cc_info =~ /yes/i ) {
            $save1 = $form_data{'Ecom_Payment_Card_Number'};
            $save1 =~ s/0$/%ZERO%/;
            $save1 =~ s/2$/%TWO%/;
            $save1 =~ s/4$/%FOUR%/;
            $save1 =~ s/6$/%SIX%/;
            $save1 =~ s/8$/%EIGHT%/;
            $form_data{'Ecom_Payment_Card_Number'} = scramble( $save1, $mypass, 0 );
            $save2 = $form_data{'Ecom_Payment_BankAcct_Number'};
            $save2 =~ s/0$/%ZERO%/;
            $save2 =~ s/2$/%TWO%/;
            $save2 =~ s/4$/%FOUR%/;
            $save2 =~ s/6$/%SIX%/;
            $save2 =~ s/8$/%EIGHT%/;
            $form_data{'Ecom_Payment_BankAcct_Number'} =  scramble( $save2, $mypass, 0 );
            $save3 = $form_data{'Ecom_Payment_BankRoute_Number'};
            $save3 =~ s/0$/%ZERO%/;
            $save3 =~ s/2$/%TWO%/;
            $save3 =~ s/4$/%FOUR%/;
            $save3 =~ s/6$/%SIX%/;
            $save3 =~ s/8$/%EIGHT%/;
            $form_data{'Ecom_Payment_BankRoute_Number'} = scramble( $save3, $mypass, 0 );
            $save4 = $form_data{'Ecom_Payment_Bank_Name'};
            $form_data{'Ecom_Payment_Bank_Name'} = scramble( $save4, $mypass, 0 );
            $save5 = $form_data{'Ecom_Payment_Orig_Card_Number'};
            $form_data{'Ecom_Payment_Orig_Card_Number'} = scramble( $save5, $mypass, 0 );
        }

        codehook('calculate_final_values_calc_save_verify_file_section_two');

        # now include all the form variables
        foreach $inx ( sort( keys %form_data ) ) {
            $value = $form_data{$inx};
            $value =~ s/\'/\"/g;

            # to prevent massive text entries in xcomments and other fields
            if ( length($value) > $sc_max_char_length ) {
                $value = substr( $value, 0, $sc_max_char_length );
            }

            $value =~ s/\"/\&quot\;/g;
            print MYFILE "\$eform_$inx = '$value'\;\n";
            print MYFILE "\$eform{'$inx'} = '$value'\;\n";
            $eform_data{$inx} = $value;  # save this back for current operations
        }

        if ( $sc_scramble_cc_info =~ /yes/i ) {
            $form_data{'Ecom_Payment_Card_Number'}      = $save1;
            $form_data{'Ecom_Payment_BankAcct_Number'}  = $save2;
            $form_data{'Ecom_Payment_BankRoute_Number'} = $save3;
            $form_data{'Ecom_Payment_Bank_Name'}        = $save4;
            $form_data{'Ecom_Payment_Orig_Card_Number'} = $save5;
        }

        codehook('calculate_final_values_calc_save_verify_file_bottom');

        print MYFILE "1;\n";
        close(MYFILE);
    }
    elsif ( ( $sc_global_bot_tracker ne '1' ) && $form_data{'shortcut_button'} && $form_data{'gateway'} && $form_data{'order_api_mode'} && ( $sc_API_access_gateways_allowed =~ /$form_data{'shortcut_button'}/ ) && ( $sc_API_access_gateways_allowed =~ /$form_data{'gateway'}/ ) && ( $sc_API_access_double_check_string =~ /$form_data{'order_api_mode'}/ ) ) {
        if ( $sc_global_bot_tracker ne '1' ) {
            codehook('api_insert_point_no_save_verify_file');
        }
    }

    codehook('end_final_values');

    return (
        $final_shipping,             $final_discount,
        $final_sales_tax,            $final_extra_tax1,
        $final_extra_tax2,           $final_extra_tax3,
        format_price($grand_total), $final_buySafe, $final_PST_tax
    );

}    # end calculate_final_values

########################################################################
#                  calculate_shipping Subroutine
########################################################################
#
# subroutine: calculate_shipping
#   Usage:
#        $shipping =
#          calculate_shipping($sub_total,
#            $total_quantity,
#            $total_measured_quantity);
#
#   Parameters:
#     $sub_total = the subtotal to calculate shipping on
#     $total_quantity = quantity of items to calc shipping on
#     $total_measured_quantity = quanity of measured item to
#                                calc shipping on
#
#   Output:
#     The value of the shipping
#
########################################################################

sub calculate_shipping {
    local ( $subtotal, $total_quantity, $total_measured_quantity ) = @_;
    local ( $test_logic_thingy ) = 0;
    $sc_custom_logic_calculated_successfully = '';

    # This routine calls the calculate
    # general logic subroutine
    # by passing it a reference to the
    # shipping logic and order form
    # shipping related fields variable

    if ( $form_data{'dc'} || $form_data{'display_cart'} ||  $form_data{'submit_deletion_button.x'} || $form_data{'submit_change_quantity_button.x'} ) {
        if ( -f "$sc_verify_order_path" ) { read_verify_file(); }
    }

    if ( $eform_Ecom_ShipTo_Method && !$form_data{'Ecom_ShipTo_Method'} ) {
        $form_data{'Ecom_ShipTo_Method'} = $eform_Ecom_ShipTo_Method;
    }

    my $temp_ship_name = $form_data{'Ecom_ShipTo_Method'};
    ( $form_data{'Ecom_ShipTo_Method'}, $junk ) = split( / \(/, $form_data{'Ecom_ShipTo_Method'}, 2 );

    codehook('calculate_shipping_top');

    my $ship_rate_calc = calculate_general_logic(
        $subtotal, $total_quantity,
        $total_measured_quantity, *sc_shipping_logic,
        *sc_order_form_shipping_related_fields
    );

    $form_data{'Ecom_ShipTo_Method'} = $temp_ship_name;
    $sc_custom_logic_run_for_shipping = 'yes';
    return $ship_rate_calc;

}

########################################################################
#                  calculate_discount Subroutine
########################################################################
#
# subroutine: calculate_discount
#   Usage:
#        $discount =
#          calculate_discount($sub_total,
#            $total_quantity,
#            $total_measured_quantity);
#
#   Parameters:
#     $sub_total = the subtotal to calculate discount on
#     $total_quantity = quantity of items to calc discount on
#     $total_measured_quantity = quanity of measured item to
#                                calc discount on
#
#   Output:
#     The value of the discount
#
########################################################################

sub calculate_discount {
    local ( $subtotal, $total_quantity, $total_measured_quantity, $status ) = @_;
    local ( $test_logic_thingy ) = 1;

    # This routine calls the calculate
    # general logic subroutine
    # by passing it a reference to the
    # discount logic and order form
    # discount related fields variable

    if ( $form_data{'dc'} || $form_data{'display_cart'} ||  $form_data{'submit_deletion_button.x'} || $form_data{'submit_change_quantity_button.x'} ) {
        if ( -f "$sc_verify_order_path" ) { read_verify_file(); }
    }

    if ( $eform_Ecom_Discount && !$form_data{'Ecom_Discount'} ) {
        $form_data{'Ecom_Discount'} = $eform_Ecom_Discount;
    }

    codehook('calculate_discount_top');

    return (
        calculate_general_logic(
            $subtotal, $total_quantity,
            $total_measured_quantity, *sc_discount_logic,
            *sc_order_form_discount_related_fields
        )
    );
}

########################################################################
#                  calculate_general_logic Subroutine
########################################################################
#
# subroutine: calculate_general_logic
#   Usage:
#  $general_value = calculate_general_logic(
#           $subtotal,
#           $total_quantity,
#           $total_measured_quantity,
#           *general_logic,
#           *general_related_form_fields);
#
#   Parameters:
#     $sub_total = the subtotal to calculateon
#     $total_quantity = quantity of items to calc on
#     $total_measured_quantity = quanity of measured item to
#                                calc on
#     *general_logic = a reference to an array
#       which defines the logic to calculate
#       the discount or shipping with.
#     *general_related_form_fields = a reference to
#       an array in the setup file which defines what form
#       fields from the order form possibly affect the
#       calculation.
#
#   Output:
#     The final value of the calculation
#
#  DISCUSSION:
#
# This version of calculate_general_logic should be able to handle both the older
# discount and shipping matrices (circa Agora 4.0k-4b) and the new format with extended date handling.
# The old format had the following layout:
#
#     Discount Code|Subtotal|Quantity|Measured Value|Discount
#
# So for example, you might set up your discount logic like this:
#
#   @sc_discount_logic = (
#     "discount30||||30%",
#     "discount40||||40%"
#   );
#
# The new layout looks like this:
#
#     Discount Code|Subtotal Price|Quantity|Measured Value|Discount|Expiration date|Notes|P_id or Category Selector|Product ID or Category Value
#
# This allows for an expiration date or an expiration range. So you might have a grid like this:
#
#    @sc_discount_logic =  (
#        "SUMMER||||10%|6/21/2011-9/21/2013|This is my note. Hi. How are you?"
#    ) ;
#
# This version will allow you to mix and match both the newer and older logic matrices for backward compatibility.
#
########################################################################

sub calculate_general_logic {

    local ( $subtotal, $total_quantity, $total_measured_quantity,
        *general_logic, *general_related_form_fields, $logic_status_inherited )
      = @_;
    local $numFields = scalar split /\|/, @general_logic[0];
    local ( $applyMe, $compareMe ) = q{};
    local ( @logic_fields, @compare_values );
    local ( $general_value, $mysubtotal, $mytotal_quantity, $mytotal_measured_quantity, $my_logic_trigger ) = 0;

    foreach $logic_statement (@general_logic) {

        # debug
        # print "<br>##########  NEW LOGIC LINE #################################<br><br>";
        # print "logic_statement = $logic_statement<br>";

        @logic_fields = split( /\|/, $logic_statement );

        if ( $logic_fields[4] =~ /f/ig ) {
            $logic_fields[4] = '0';
        }

      FORMFIELD:
      foreach $form_field (@general_related_form_fields) {

            @compare_values = (
                "#$form_data{$form_field}#", $subtotal, $total_quantity,
                $total_measured_quantity, 0, 0, 0, 0, 0
            );

            if ( ( $logic_fields[7] ) && ( $logic_fields[8] ) ) {
                    ( $mysubtotal, $mytotal_quantity, $mytotal_measured_quantity ) = 0;
                    open( CART, "$sc_cart_path" ) || file_open_error( "$sc_cart_path", "cart_contents_general_logic",__FILE__, __LINE__ );
                    while (<CART>) {
                        my @cart_fields = split( /\|/, $_ );
                        if ( ( $logic_fields[7] eq 'PID' )  && ( $logic_fields[8] =~ /$cart_fields[$cart{'product_id'}]/ ) ) {
                            $mysubtotal += $cart_fields[ $cart{'price_after_options'} ] * $cart_fields[ $cart{'quantity'} ];
                            $mytotal_quantity += $cart_fields[ $cart{'quantity'} ];
                            $mytotal_measured_quantity += $cart_fields[ $cart{'shipping'} ] * $cart_fields[ $cart{'quantity'} ];
                            $compare_values[7] = $logic_fields[7];
                            $compare_values[8] = $logic_fields[8];
                        }
                        elsif ( ( $logic_fields[7] eq 'Category' ) &&  ( $logic_fields[8] eq "$cart_fields[ $cart{'product'} ]" ) ) {
                            $mysubtotal +=  $cart_fields[ $cart{'price_after_options'} ] * $cart_fields[ $cart{'quantity'} ];
                            $mytotal_quantity += $cart_fields[ $cart{'quantity'} ];
                            $mytotal_measured_quantity += $cart_fields[ $cart{'shipping'} ] * $cart_fields[ $cart{'quantity'} ];
                            $compare_values[7] = $logic_fields[7];
                            $compare_values[8] = $logic_fields[8];
                        }
                    }
                    close(CART);
                     if ( $logic_status_inherited !~ /yes/i ) {
                         $compare_values[1] = $mysubtotal;
                         $compare_values[2] = $mytotal_quantity;
                         $compare_values[3] = $mytotal_measured_quantity;
                     }
                     else {
                         $compare_values[1] = $compare_values[1] - $mysubtotal;
                         $compare_values[2] = $compare_values[2] - $mytotal_quantity;
                         $compare_values[3] = $compare_values[3] - $mytotal_measured_quantity;
                     }
            }

            if ( $logic_fields[7] && $logic_fields[8] ) {
                my $test7 = compare_logic_values( $compare_values[7], $logic_fields[7] );
                my $test8 = compare_logic_values( $compare_values[8], $logic_fields[8] );
                next FORMFIELD if ( !( $test7  && $test8 ) );
                $my_logic_trigger = 1;
            }

            for ( 0 .. $numFields ) {
                 # 4 is cost/rate to apply, 6 is the description, 7 is PID or category, 8 is the ID or category name. Don't compare those 4 fields
                next if $_ == 4 || $_ == 6 || $_ == 7 || $_ == 8;
                # debug
                # print "form_field = $form_field  ...  logic_fields[$_] = $logic_fields[$_]<br>";
                my $logicField = $logic_fields[$_];

                #If we are evaluating the first field and it has something in it, make the comparison exact
                $logicField = "#$logic_fields[$_]#" if $logic_fields[$_] && !$_;

                # if first field not blank and not a match, skip to next line of logic. Skips comparing other fields in same line
                # If first field blank, compares all other fields that apply.
                next FORMFIELD if ( !( compare_logic_values( $compare_values[$_], $logicField ) )  );
            }

            $applyMe = $logic_fields[4];
            $sc_custom_logic_calculated_successfully = 1;

            # debug
            # print "applyMe = $applyMe<br>";

             # if percentage sign
            if ( $applyMe =~ /%/ ) {
                $applyMe =~ s/%//;
                if ( $my_logic_trigger == 1 ) {
                    $general_value += ( $subtotal * $applyMe ) / 100;

                }
                else {
                    if ( ( $mysubtotal eq '' && $subtotal ne '' ) || ( $mysubtotal == 0 && $subtotal > 0 ) ) {
                        $general_value += ($subtotal * $applyMe) / 100;
                    }
                    else {
                        $general_value += ($mysubtotal * $applyMe) / 100;
                    }
                }
            }
            else {
                $general_value += $applyMe;
            }
            $my_logic_trigger = 0;
        }    # End of loop for each form field
    }    # End of loop for each logic statement

    # just in case discount exceeds subtotal,
    # so merchant doesn't inadvertantly give refunds with long chains of discount logic or negative shipping rates in logic
    if ( ( $test_logic_thingy == 1 ) && ( $general_value > $subtotal ) )  {
        return ( format_price($subtotal) );
    }

     return ( format_price($general_value) );

}

########################################################################
#                  calculate_extra_tax1 Subroutine
########################################################################
#
# subroutines: calculate_extra_taxn
#   Usage:
#        $extra_taxn =
#          calculate_extra_taxn($sub_total);
#
# Note: theses are experimental "dummy" routines that
# will be moved to custom logic code
#
#   Parameters:
#     $sub_total = the subtotal to calculate sales tax on
#
#   Output:
#     The value of the sales tax
#
########################################################################

sub calculate_extra_tax1 {
    local ($subtotal)  = @_;
    my ($extra_tax) = 0;
    if ( $sc_use_tax1_logic =~ /yes/i ) {
        $sc_extra_tax1_name = "Tax1" if $sc_extra_tax1_name eq '';
        $extra_tax =
          eval_custom_logic( $sc_extra_tax1_logic,"$agora_extra_tax_title01 1", __FILE__, __LINE__ );
    }
    if (  $extra_tax > 0 ) {
         $extra_tax += 0.0001;
         if ( $sc_sales_tax_roundat4 eq 'Yes' ) {
            $sales_tax += 0.001;
        }
    }
    return ( format_price($extra_tax) );
}    # End of calculate extra tax 1

########################################################################
#                  calculate_extra_tax2 Subroutine
########################################################################

sub calculate_extra_tax2 {
    local ($subtotal)  = @_;
    my ($extra_tax) = 0;
    if ( $sc_use_tax2_logic =~ /yes/i ) {
        $sc_extra_tax2_name = "Tax2" if $sc_extra_tax2_name eq '';
        $extra_tax =
          eval_custom_logic( $sc_extra_tax2_logic,"$agora_extra_tax_title01 2", __FILE__, __LINE__ );
    }
    if (  $extra_tax > 0 ) {
         $extra_tax += 0.0001;
    }
    return ( format_price($extra_tax) );
}    # End of calculate extra tax 2

########################################################################
#                  calculate_extra_tax3 Subroutine
########################################################################

sub calculate_extra_tax3 {
    local ($subtotal)  = @_;
    my ($extra_tax) = 0;
    if ( $sc_use_tax1_logic =~ /yes/i ) {
        $sc_extra_tax3_name = "Tax3" if $sc_extra_tax3_name eq '';
        $extra_tax =
          eval_custom_logic( $sc_extra_tax3_logic,"$agora_extra_tax_title01 3", __FILE__, __LINE__ );
    }
    if (  $extra_tax > 0 ) {
         $extra_tax += 0.0001;
    }
    return ( format_price($extra_tax) );
}    # End of calculate extra tax 3

########################################################################
#                  calculate_sales_tax Subroutine
########################################################################
#
# subroutine: calculate_sales_tax
#   Usage:
#        $sales_tax =
#          calculate_sales_tax($taxable_grand_total);
#
#   Parameters:
#     $sub_total = the subtotal to calculate sales tax on
#
#   Output:
#     The value of the sales tax
#
########################################################################

sub calculate_sales_tax {
    local ($taxable_grand_total) = @_;
    local ($sales_tax)           = 0;
    local ($tax_form_variable) = q{};
    local ($continue) = 1;

    codehook( 'calc_sales_tax_top' );

    # code hook has set tax, can return
    if ( $continue == 0 ) {
        return ( format_price($sales_tax) );
    }

    # If the sales tax is dependant on a form variable, then
    # we check the value of that form
    # variable against the possible values
    # that have been designated in the
    # @sc_sales_tax_form_variable array.
    #
    # A match results in the sales tax being calculated.

    $tax_form_variable = $form_data{$sc_sales_tax_form_variable};
    if ( $tax_form_variable eq '' ) {    # try the eform value ...
        $tax_form_variable = $eform{$sc_sales_tax_form_variable};
    }

    if ( $sc_sales_tax_form_variable ) {
        foreach $value (@sc_sales_tax_form_values) {
            # EU VAT tax
            if ( ( $value =~ /^European Union$/ ) && ( ${tax_form_variable} =~ /^Austria$|^Belguim$|^Cyprus$|^Bulgaria$|^Czech Republic$|^Denmark$|^Estonia$|^Finland$|^France$|^Germany$|^Greece$|^Hungary$|^Ireland$|^Italy$|^Latvia$|^Lithuania$|^Luxemborg$|^Malta$|^Netherlands$|^Poland$|^Portugal$|^Romania$|^Slovakia$|^Spain$|^Sweden$|^United Kingdom$/i ) ) {
                $sales_tax = $taxable_grand_total * $sc_sales_tax;
            }
            elsif (   ( $value =~ /^${tax_form_variable}$/i ) && ( ${tax_form_variable} ) )  {
                # Canadian HST
                if ( ( $value =~ /^Canada$/i ) && ( $form_data{'Ecom_ShipTo_Postal_StateProv'} =~ /^BC$|^ON$|^NS$|^NB$|^NL$|^NFLD$/ ) ) {
                    $sales_tax = $taxable_grand_total * $sc_sales_tax;
                }
                # Canadian GST tax
                elsif ( ( $value =~ /^Canada$/i ) && ( $form_data{'Ecom_ShipTo_Postal_StateProv'} =~ /^NT$|^NWT$|^NU$|^YT$|^YK$|^AB$|^MB$|^SK$|^QC$|^PQ$|^PE$|^PEI$/ ) ) {
                    $sales_tax = $taxable_grand_total * $sc_GSTsales_tax;
                }
                # US State Tax
                else {
                    $sales_tax = $taxable_grand_total * $sc_sales_tax;
                }
            }

        }

        # If it is not form variable
        # dependant, then the sales tax is always calculated

    }
    else {
        $sales_tax = $taxable_grand_total * $sc_sales_tax;
    }

    codehook( 'calc_sales_tax_bot' );

    if ( $sales_tax > 0 ) {
        $sales_tax += 0.0001;
        if ( $sc_sales_tax_roundat4 eq 'Yes' ) {
            $sales_tax += 0.001;
        }
    }

    # We return the sales tax already in a preformatted form.
    return ( format_price($sales_tax) );

}    # End of calculate sales tax

########################################################################
#                  calculate_PSTsales_tax Subroutine
########################################################################
#
# subroutine: calculate_PSTsales_tax
#   Usage:
#        $sales_PSTtax =
#          calculate_PSTsales_tax($taxable_grand_total);
#
#   Parameters:
#     $sub_total = the subtotal to calculate sales tax on
#
#   Output:
#     The value of the Canadian PST sales tax
#
########################################################################

sub calculate_PSTsales_tax {
    local ($taxable_grand_total) = @_;
    local ($sales_tax)           = 0;
    local ($tax_form_variable) = q{};


    $tax_form_variable = $form_data{$sc_sales_tax_form_variable};
    if ( $tax_form_variable eq '' ) {    # try the eform value ...
        $tax_form_variable = $eform{$sc_sales_tax_form_variable};
    }

    if ( $sc_sales_tax_form_variable ) {
        foreach $value (@sc_sales_tax_form_values) {
            if (   ( $value =~ /^${tax_form_variable}$/i ) && ( ${tax_form_variable} ) && ( $form_data{'Ecom_ShipTo_Postal_StateProv'} =~ /^MB$|^SK$|^QC$|^PQ$|^PEI$|^PE$/i ) )  {
                $sales_tax = $taxable_grand_total * $sc_PSTsales_tax;
            }
        }

        # If it is not form variable
        # dependant, then the sales tax is always calculated
    }
    else {
        $sales_tax = $taxable_grand_total * $sc_PSTsales_tax;
    }

    if ( $sales_tax > 0 ) {
        $sales_tax += 0.0001;
        if ( $sc_sales_tax_roundat4 eq 'Yes' ) {
            $sales_tax += 0.001;
        }
    }
    # We return the sales tax already in a preformatted form.
    return ( format_price($sales_tax) );

}    # End of PST calculate sales tax

########################################################################
#                  compare_logic_values Subroutine
########################################################################
#
# subroutine: compare_logic_values
#   Usage:
#        $boolean_value =
#          calculate_logic_values($input_value,
#                                  $value_to_compare);
#
#   Parameters:
#     $input_value = the value we are performing the
#        logic on.
#     $value_to_compare = the logical value. This can also
#        be a RANGE (indicated with a hyphen). The range
#        can also be open-ended (eg 1-,-5, etc...)
#
#   Output:
#     $boolean_value = 1 if true, 0 if false compare
#
# Updated August 29 2004 & April 17, 2007
#
########################################################################

sub compare_logic_values {
    local ( $input_value, $value_to_compare ) = @_;
    local ( $lowrange, $highrange ) = q{};

    my $rangeCount =
      scalar( ( $lowrange, $highrange ) = split( /-/, $value_to_compare ) );

    # If its a date, use date analysis
    if ( $value_to_compare =~ /\// ) {
        ( $highrange, $lowrange ) = ( $lowrange, '' )
          if $lowrange && !$highrange && $rangeCount == 1;
        $epochStart = date_to_epoch( $lowrange  || '1/1/1970', 'start' );
        $epochEnd   = date_to_epoch( $highrange || '1/1/2030', 'end' );
        return ( ( time() >= $epochStart ) && ( time() <= $epochEnd ) ) ? 1 : 0;
    }

    if ( $rangeCount > 1 ) {

        if ( $lowrange eq '' ) {
            if ( $input_value <= $highrange ) {
                return (1);
            }
            else {
                return (0);
            }

        }
        elsif ( $highrange eq '' ) {
            if ( $input_value >= $lowrange ) {
                return (1);
            }
            else {
                return (0);
            }

        }
        else {
            if (   ( $input_value >= $lowrange ) && ( $input_value <= $highrange ) )  {
                return (1);
            }
            else {
                return (0);
            }
        }

    }
    else {
        if (   ( $input_value =~ /$value_to_compare/i ) || ( $value_to_compare eq '' ) )   {
            return (1);
        }
        else {
            return (0);
        }
    }
}    # EOS ompare_logic_values

#######################################################################

sub date_to_epoch {
    use Time::Local;
    local ( $stringDate, $part_of_day ) = @_;
    local @mredDate = split '/', $stringDate;
    return timelocal( 0, 0, 0, $mredDate[1], $mredDate[0] - 1, $mredDate[2] )
      if ( $part_of_day =~ /start/ );
    return timelocal( 59, 59, 23, $mredDate[1], $mredDate[0] - 1, $mredDate[2] )
      if ( $part_of_day =~ /end/ );

}

#######################################################################

sub decode_verify_vars {

    if ( ( $sc_test_repeat ne 0 )
        || (   ( $form_data{'HCODE'} eq '' )
            && ( $sc_scramble_cc_info =~ /yes/i ) ) )   {
        $eform_Ecom_Payment_BankAcct_Number  = q{};
        $eform_Ecom_Payment_BankCheck_Number = q{};
        $eform_Ecom_Payment_BankRoute_Number = q{};
        $eform_Ecom_Payment_Bank_Name        = q{};
        $eform_Ecom_Payment_Card_Number      = q{};
        $eform_Ecom_Payment_Orig_Card_Number = q{};
    }
    else {
        if ( $sc_scramble_cc_info =~ /yes/i ) {
            my $mypass = $form_data{'HCODE'};
            my $save1  = $eform_Ecom_Payment_Orig_Card_Number;
            $eform_Ecom_Payment_Orig_Card_Number = scramble( $save1, $mypass, 1 );
            $eform_Ecom_Payment_Orig_Card_Number =~ s/%ZERO%$/0/;
            $eform_Ecom_Payment_Orig_Card_Number =~ s/%TWO%$/2/;
            $eform_Ecom_Payment_Orig_Card_Number =~ s/%FOUR%$/4/;
            $eform_Ecom_Payment_Orig_Card_Number =~ s/%SIX%$/6/;
            $eform_Ecom_Payment_Orig_Card_Number =~ s/%EIGHT%$/8/;
            $save1 = $eform_Ecom_Payment_Card_Number;
            $eform_Ecom_Payment_Card_Number = scramble( $save1, $mypass, 1 );
            $eform_Ecom_Payment_Card_Number =~ s/%ZERO%$/0/;
            $eform_Ecom_Payment_Card_Number  =~ s/%TWO%$/2/;
            $eform_Ecom_Payment_Card_Number  =~ s/%FOUR%$/4/;
            $eform_Ecom_Payment_Card_Number  =~ s/%SIX%$/6/;
            $eform_Ecom_Payment_Card_Number  =~ s/%EIGHT%$/8/;
            $save1 = $eform_Ecom_Payment_BankAcct_Number;
            $eform_Ecom_Payment_BankAcct_Number = scramble( $save1, $mypass, 1 );
            $eform_Ecom_Payment_BankAcct_Number =~ s/%ZERO%$/0/;
            $eform_Ecom_Payment_BankAcct_Number =~ s/%TWO%$/2/;
            $eform_Ecom_Payment_BankAcct_Number =~ s/%FOUR%$/4/;
            $eform_Ecom_Payment_BankAcct_Number =~ s/%SIX%$/6/;
            $eform_Ecom_Payment_BankAcct_Number =~ s/%EIGHT%$/8/;
            $save1 = $eform_Ecom_Payment_BankRoute_Number;
            $eform_Ecom_Payment_BankRoute_Number = scramble( $save1, $mypass, 1 );
            $eform_Ecom_Payment_BankRoute_Number =~ s/%ZERO%$/0/;
            $eform_Ecom_Payment_BankRoute_Number =~ s/%TWO%$/2/;
            $eform_Ecom_Payment_BankRoute_Number =~ s/%FOUR%$/4/;
            $eform_Ecom_Payment_BankRoute_Number =~ s/%SIX%$/6/;
            $eform_Ecom_Payment_BankRoute_Number =~ s/%EIGHT%$/8/;
            $save1 = $eform_Ecom_Payment_Bank_Name;
            $eform_Ecom_Payment_Bank_Name = scramble( $save1, $mypass, 1 );
        }
    }
    codehook( 'done_verify_decode' );
}

#######################################################################

sub load_verify_file {
    read_verify_file();
    clear_verify_file();
}

#######################################################################

sub clear_verify_file {
    codehook( 'before-clear-verify-file' );
    eval("unlink  \"$sc_verify_order_path\";");
    codehook( 'after-clear-verify-file' );
}

#######################################################################

sub read_verify_file {

    codehook( 'before-read-verify-file' );

    eval("require \"$sc_verify_order_path\";");
    decode_verify_vars();

    codehook( 'after-read-verify-file' );

    my $str1            = "$agora_orderlog01\n\n";
    my $str2            = "$agora_orderlog02: $sc_verify_ip_addr\n\n";
    my $str3            = format_XCOMMENTS();
    $XCOMMENTS_ADMIN = $str1 . $str2 . $str3;
    $XCOMMENTS       = $str1 . $str3;

    codehook('end-read-verify-file');
}

#######################################################################

sub empty_cart {
    codehook( 'before-empty-cart' );

    open( CART, ">$sc_cart_path" ) || order_warn("$agora_orderwarn01");
    print CART '';
    close(CART);

    codehook( 'after-empty-cart' );
}

#######################################################################

sub order_warn {
    local ($str) = @_;
    print "<br><b>$str</b><br>\n";
}

#######################################################################

sub display_calculations {

    local ( $taxable_grand_total, $subtotal, $are_we_before_or_at_process_form,
        $total_measured_quantity )
      = @_;

    local (
        $final_shipping,   $final_discount,   $final_sales_tax,
        $final_extra_tax1, $final_extra_tax2, $final_extra_tax3,
        $grand_total, $final_buySafe, $final_PST_tax
    );

    if ( $sc_use_verify_values_for_display =~ /yes/i ) {
        ( $sc_ship_method_shortname, $junk ) =
          split( /\(/, $sc_verify_shipto_method, 2 );
        (
            $final_shipping,   $final_discount,   $final_sales_tax,
            $final_extra_tax1, $final_extra_tax2, $final_extra_tax3,
            $grand_total, $final_buySafe, $final_PST_tax
          )
          = (
            $sc_verify_shipping,    $sc_verify_discount,
            $sc_verify_tax,         $sc_verify_etax1,
            $sc_verify_etax2,       $sc_verify_etax3,
            $sc_verify_grand_total, $sc_verify_buySafe,
            $sc_verify_PSTtax
          );
    }
    else {
        (
            $final_shipping,   $final_discount,   $final_sales_tax,
            $final_extra_tax1, $final_extra_tax2, $final_extra_tax3,
            $grand_total, $final_buySafe, $final_PST_tax
          )
          = calculate_final_values( $taxable_grand_total, $subtotal,
            $total_quantity, $total_measured_quantity,
            $are_we_before_or_at_process_form );
    }

    # set these as global variables for possible use later
    $zsubtotal         = $subtotal;
    $zfinal_shipping   = $final_shipping;
    $zfinal_discount   = $final_discount;
    $zfinal_sales_tax  = $final_sales_tax;
    $zfinal_extra_tax1 = $final_extra_tax1;
    $zfinal_extra_tax2 = $final_extra_tax2;
    $zfinal_extra_tax3 = $final_extra_tax3;
    $zfinal_PSTsales_tax  = $final_PST_tax;
    $zfinal_buySafe    = $final_buySafe;
    if ( $subtotal < .000000001 ) {
        $zfinal_buySafe = q{};
    }
    $zgrand_total = $grand_total;

    if ( $final_shipping > 0 ) {
        $final_shipping = format_price($final_shipping);
        $final_shipping = display_price($final_shipping);
    }

    if ( $final_discount > 0 ) {
        $final_discount      = format_price($final_discount);
        $final_discount      = display_price($final_discount);
    }

    if ( $final_sales_tax > 0 ) {
        $final_sales_tax      = format_price($final_sales_tax);
        $final_sales_tax      = display_price($final_sales_tax);
    }

    if ( $final_PST_tax > 0 ) {
        $final_PST_tax      = format_price($final_PST_tax);
        $final_PST_tax      = display_price($final_PST_tax);
    }

    if ( ( $final_buySafe > 0 ) && ( $subtotal > 0 ) ) {
        $final_buySafe      = format_price($final_buySafe);
        $final_buySafe      = display_price($final_buySafe);
    }
    else {
        $final_buySafe = q{};
    }

    $authPrice   = $grand_total;
    $grand_total = display_price($grand_total);

    if ( $reason_to_display_cart ) {
        #print_order_totals_checkout();
        print_order_totals();
    }
    else {
        print_order_totals();
    }


    if ( $are_we_before_or_at_process_form =~ /at/i ) {
        print <<ENDOFTEXT;
</form>
ENDOFTEXT

    }

    return;

}

#######################################################################

sub explode {

    #
    # Explode a code so that the code and value are returned.
    # Given a hash value:
    #  $zdata{'myvalcode'} = 'Q';
    # and a val code table with an entry like:
    #  $myvalcode{'Q'} = "Quiet";
    # Notice the table and the hash key are the same name ... anyway,
    # explode('myvalcode',*zdata) returns with:
    #  "Q Quiet"
    #
    local ( $what, *zdata ) = @_;
    local ( $temp, $ans, $command );

    codehook( 'explode_top' );
    $temp = $zdata{$what};
    $temp =~ /([\w\-\=\+\/]+)/;
    $temp    = $1;
    $ans     = $temp . " ";
    $command = '$ans .= $' . $what . '{"' . $temp . '"};';
    eval($command);
    codehook( 'explode_bot' );
    return $ans;
}

#######################################################################

sub format_XCOMMENTS {
    local ($str, $inx ) = q{};

    codehook( 'format_XCOMMENTS_top' );

    foreach my $mykey ( sort( grep( /\_XCOMMENT\_/, ( keys %eform ) ) ) ) {
        if ( $eform{$mykey} ) {
            my ( $junk, $val ) = split( /\_XCOMMENT\_/, $mykey, 2 );
            $val =~ s/\_/\ /g;
            $str .= $val . ":\n" . $eform{$mykey} . "\n\n";
        }
    }

    codehook( 'format_XCOMMENTS_bot' );

    return $str;
}

#######################################################################
#
# Copyright Steve Kneizys 11-FEB-2000, used by permission.
# This subroutine is not meant to be encryption ... it simply
# scrambles things a tad so it doesn't look like it used to
# so that prying eyes don't know what it is at a quick glance.
# This program can be written MUCH more simply, but ...
# "security through obscurity"!  Don't want to violate USA
# export restrictions ... otherwise we'd really encrypt things.
# Based on a "children's spy decoder ring".  An easier way to do
# this would be to translate numbers to letters :)
#
# Usage: scramble($the_string,$phrase,$direction);
#
# $direction: encode with 0 then decode with 1 (or vice versa!)
# $phrase: passphrase to recover the answer
#
#######################################################################

sub scramble {
    my ( $what, $salt, $direction ) = @_;
    if ( $what eq '' ) { return ''; }
    $what = scramble_engine( $what, $salt, $direction );
    $what = scramble_engine( reverse($what), $salt, $direction );
    return $what;
}

#######################################################################

sub scramble_engine {
    my ( $key, $mysalt, $backout ) = @_;
    my ($part1) = 'abcdefghijklmnopqrstuvwxyz';
    my ( $part3, $ans, $ans2 ) = q{};
    my ($val, $val2, $val3, $val4)              = 0;
    my ($scramble_variable) = 25;
    my ( $a1, $a2, $rev_last_char, $rev_this_char ) =  q{};
    my $part2 = $part1;
    $part2 =~ tr/a-z/A-Z/;
    my $the_code = " 1234567890,.<>/?;:[}]{\|=+-_)(*&^%\$#\@!~" . $part1 . $part2;
    my $the_list = $the_code;
    my $the_ref  = reverse($the_code);
    my $ml   = length($the_code);

    # use the salt on $the_ref
    $mysalt .= '*';
    for ( $x1 = 1 ; $x1 < length($mysalt) ; $x1++ ) {
        my $inx = index( $the_ref, substr( $mysalt, $x1, 1 ) );
        if ( $inx > 0 ) {
            $part1 = substr( $mysalt, $x1, 1 ) . substr( $the_ref, 0, $inx );
            $part2 = substr( $the_ref, $inx + 1, 999 );

            #print $x1," ",substr($mysalt,$x1,1)," ",$inx,"\n";
            #print $the_ref,"\n";
            #print $part1,$part2,"\n";
            $the_ref = reverse( $part1 . $part2 );
        }
    }

    for ( $x1 = 1 ; $x1 < $scramble_variable ; $x1++ ) {

        # setup/scramble the translate table just for fun
        $part1 = substr( $the_ref, 0,  10 );
        $part2 = substr( $the_ref, 10, 25 );
        $part3 = substr( $the_ref, 35, ( length($the_ref) - 35 ) );
        $the_ref = reverse( $part2 . reverse($part1) . $part3 );
    }

    #print "code=$the_code\n";
    #print " ref=$the_ref\n";

    my $key = reverse($key);
    while ( $key ) {
        my $inx       = chop($key);
        my $last_char = $this_char;
        my $this_char = $inx;

        #  print "inx = $inx ",ord($inx), "\n";
        if ( index( $the_code, $inx ) >= 0 ) {    # found in our set

            #$val=0;$val2=0;$val3=0;$val4=0;
            $val  = index( $the_code, $inx ) + $val;
            $val3 = index( $the_ref,  $inx );
            $val2 = $val3 - $val4;
            $val4 = $val3;
            while ( $val2 < 0 ) {
                $val2 = $val2 + length($the_ref);
            }
            while ( $val >= length($the_ref) ) {
                $val = $val - length($the_ref);
            }

            #   print "val,val2 = $val, $val2\n";
            $ans  .= substr( $the_code, $val2, 1 );
            $ans2 .= substr( $the_ref,  $val,  1 );
        }
        else {
            $ans  .= $inx;
            $ans2 .= $inx;
        }
    }

    #print "ans = $ans    ans2 = $ans2 \n";
    if ( $backout == '1' ) {
        return $ans2;
    }
    else {
        return $ans;
    }
}

#######################################################################

sub generate_invoice_number {
    local ($invoice_number) = q{};

    codehook('generate_invoice_number');

    if ( $invoice_number eq '' ) {
        $invoice_number = time;
    }
    return $invoice_number;
}


#######################################################################

1;
