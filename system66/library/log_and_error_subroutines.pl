$versions{'log_and_error_subroutines.pl'} = '06.6.00.0002';

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
# Contains the subroutines/functions for errors and misc logging:
#       access logs
#       file open errors
#       update error logs
#
#

########################################################################
#                      Log Access to Store
########################################################################

sub log_access_to_store {

    if ( ( form_check('submit_order_form_button') )
          || ( form_check('gateway') )
          || ( form_check('order_api_mode') )
          || ( form_check('USER1') )
          || ( form_check('order_form_button') )
          || ( form_check('submit_change_quantity_button') )
          || ( form_check('submit_deletion_button') )
          || ( form_check('token') )
       )
    { return; }

    $date = get_date();
    get_file_lock("$sc_access_log_path.lockfile");
    open( ACCESS_LOG, ">>$sc_access_log_path" );

    $remote_addr  = $ENV{'REMOTE_ADDR'};
    $request_uri  = $ENV{'REQUEST_URI'};
    $http_user_agent = $ENV{'HTTP_USER_AGENT'};

    if ( $ENV{'HTTP_REFERER'} ) {
        $http_referer = $ENV{'HTTP_REFERER'};
    }
    else {
        $http_referer = "possible bookmarks";
    }

    $remote_host = $ENV{'REMOTE_HOST'};

    $shortdate = get_date_short();
    chomp($shortdate);
    $unixdate = time;

    $new_access =
        "$form_data{'url'}\|$shortdate\|$request_uri"
      . "\|$cookie{'visit'}\|$remote_addr\|$http_user_agent"
      . "\|$http_referer\|$unixdate\|";

    # The script then takes off the final pipe, adds the new
    # access to the log file, closes the log file and removes
    # the lock file.
    chop $new_access;
    print ACCESS_LOG "$new_access\n";
    close(ACCESS_LOG);

    release_file_lock("$sc_access_log_path.lockfile");
}


########################################################################
#                  update_error_log Subroutine
########################################################################
#
# update_error_log is used to append to the error log if
# there has been a process executing this script and/or
# email the admin.
#
# The subroutine takes three arguments, the type of error,
# the current filename and current line number and is
# called with the following syntax:
#
# &update_error_log("WARNING", __FILE__, __LINE__);
#
#######################################################################

sub update_error_log {

    # The subroutine begins by assigning the incoming
    # arguments to local variables and defining some other
    # local variables to use during its work.
    #
    # $type_of_error will be a text string explaining what
    # kind of error is being logged.
    #
    # $file_name is the current filename of this script.
    #
    # $line_number is the line number on which the error
    # occurred.  Note that it is essential that the line
    # number, stored in __LINE__ be passed through all levels
    # of subroutines so that the line number value will truly
    # represent the line number of the error and not the
    # line number of some subroutine for error handling.

    local ( $type_of_error, $file_name, $line_number ) = @_;
    local ( $log_entry, $email_body, $variable, @env_vars );

    # The list of the HTTP environment variables are culled
    # into the @env_vars list array and get_date is used to
    # assign the current date to $date
    @env_vars = sort( keys(%ENV) );
    $date     = get_date();

    # Now, if the admin has instructed the script to log
    # errors by setting $sc_shall_i_log_errors in
    # agora_setup.pl, the script will create an error log
    # entry.
    if ( $sc_debug_mode eq 'yes' ) {
        if ( $sc_header_printed ne 1 ) {
            if ( $sc_browser_header eq '' ) {
                $sc_browser_header = "Content/type: text/html;\n\n";
            }
            print $sc_browser_header;
        }

        local ($browser_text) = $type_of_error;
        $browser_text =~ s/\|/\<br>\n/g;

        print '<DIV ALIGN=LEFT><TABLE WIDTH=500><TR><TD>' . "\n<PRE>";
        print "$agora_error_notice_title01$browser_text<br>",
          "$agora_error_notice_title02: $file_name<br>",
          "$agora_error_notice_title03: $line_number<BR>\n";
        print '</PRE></TD></TR></TABLE></DIV>' . "\n";

    }

    if ( $sc_shall_i_log_errors eq 'yes' ) {

        # First, the new log entry row is created as a pipe
        # delimited list beginning with the error type, filename,
        # line number and current date.
        $log_entry =
"$type_of_error\|$agora_error_notice_title02=$file_name\|$agora_error_notice_title03=$line_number\|";
        $log_entry .= "$agora_error_notice_title04=$date\|";

        # Then the error log file is opened securely by using the
        # lock file routines in get_file_lock discussed later.
        get_file_lock("$sc_error_log_path.lockfile");
        open( ERROR_LOG, ">>$sc_error_log_path" );
        #  || CgiDie("$agora_errorlog_openerror");

        # Now, the script adds to the log entry row, the values
        # associated with all of the HTTP environment variables
        # and prints the whole row to the log file which it then
        # closes and opens for use by other instances of this
        # script by removing the lock file.
        foreach $variable (@env_vars)

        {
            $log_entry .= "$variable: $ENV{$variable}\|";
        }

        $log_entry =~ s/\n/<br>/g;    # do not want newlines!
        print ERROR_LOG "$log_entry\n";
        close(ERROR_LOG);

        release_file_lock("$sc_error_log_path.lockfile");

        # End of if ($sc_shall_i_log_errors eq "yes")
    }

    # Next, the script checks to see if the admin has
    # instructed it to also send an email error notification
    # to the admin by setting the $sc_shall_i_email_if_error
    # in agora_setup.pl
    #
    # If so, it prepares an email with the same info contained
    # in the log file row and mails it to the admin using the
    # send_mail routine in mail-lib.pl.  Note that a common
    # source of email errors lies in the admin not setting the
    # correct path for sendmail in mail-lib.pl.
    # Make sure that you set this variable there if you are
    # not receiving your mail and you are using the sendmail
    # version of the mail-lib package.
    if ( $sc_shall_i_email_if_error eq 'yes' )

    {
        $email_body = "$type_of_error\n\n";
        $email_body .= "$agora_error_notice_title02 = $file_name\n";
        $email_body .= "$agora_error_notice_title03 = $line_number\n";
        $email_body .= "$agora_error_notice_title04=$date\|";

        foreach $variable (@env_vars) {
            $email_body .= "$variable = $ENV{$variable}\n";
        }

        require_supporting_libraries( __FILE__, __LINE__, "$sc_mail_lib_path" );

        send_mail(
            "$sc_admin_email",   "$sc_admin_email",
            "$agora_error_email_subject01", "$email_body"
        );

        # End of if ($sc_shall_i_email_if_error eq "yes")
    }

}

########################################################################
#                    file_open_error Subroutine
########################################################################
#
# If there is a problem opening a file or a directory, it
# is useful for the script to output some information
# pertaining to what problem has occurred.  This
# subroutine is used to generate those error messages.
#
# file_open_error takes four arguments: the file or
# directory which failed, the section in the code in which
# the call was made, the current file name and
# line number, and is called with the following syntax:
#
# file_open_error("file.name", "ROUTINE", __FILE__, __LINE__);
#
#######################################################################

sub file_open_error {

    # The subroutine simply uses the update_error_log
    # subroutine discussed later to modify the error log
    local ( $bad_file, $script_section, $this_file, $line_number ) = @_;

    my $temp_error_thingy =
        qq|$agora_error_notice_title05 $bad_file<br>$agora_error_notice_title06 $script_section<br>$agora_error_notice_title07 $this_file<br>$agora_error_notice_title03 #: $line_number<br>|;

    $sc_update_error_log_html =~ s/\[\[errormessage1\]\]/$agora_error_message11/;
    $sc_update_error_log_html =~ s/\[\[errormessage2\]\]/$agora_error_message12/;
    $sc_update_error_log_html =~ s/\[\[errormessage3\]\]/$agora_error_message13/;
    $sc_update_error_log_html =~ s/\[\[tempthingy\]\]/$temp_error_thingy/;
    local ( $return_thingy ) =  $sc_update_error_log_html;

    if ( $sc_global_bot_tracker ne '1' ) {    # run only if not a bot
        if  ( ( ( $bad_file eq $sc_cart_path ) || ( $bad_file =~ /$sc_user_carts_directory_path/ ) )
            && ( $sc_shall_i_log_missing_carts !~ /no/i ) ) {
                if ( $script_section =~ /expired cart/i) {
                    update_error_log( "CART SESSION OPEN ERROR (MOST LIKELY EXPIRED) - $bad_file", $this_file, $line_number );
                } else {
                    update_error_log( "FILE OPEN ERROR - $bad_file", $this_file, $line_number );
                }
        }
        print $return_thingy;
    }

}


#######################################################################

sub zcode_error {
    local ( $ZCODE, $at, $file, $line ) = @_;
    local ($xx) = "-" x 60;
    $ZCODE =~ s/\n/\|/g;
    $at    =~ s/\n/\|/g;
    update_error_log( "zcode $agora_error_message03: |$at|$ZCODE|$xx",
        $file, $line );
    call_exit();
}


########################################################################
#                  options_error_message Subroutine
######################################################################

sub options_error_message {

    standard_page_header("$agora_error_pagetitle");
    StoreHeader();
    $sc_error_message_html =~ s/\[\[errormessage\]\]/$agora_error_message06/;
    print $sc_error_message_html;
    StoreFooter();
}


#######################################################################
#                    bad_order_note Subroutine                        #
#######################################################################
# bad_order_note generates an error message for the user
# in the case that they have not submitted a valid number
# for a quantity.  It takes no arguments and is called
# with the following syntax:
#
# bad_order_note();

sub bad_order_note {

    local ($button_to_set) = @_;
    $button_to_set = 'try_again' if ( $button_to_set eq '' );

    standard_page_header("$sc_error_text01");
    StoreHeader();
    if ($sc_bad_order_note_alt) {
        $sc_error_message_html =~ s/\[\[errormessage\]\]/$sc_bad_order_note_alt/;
        print $sc_error_message_html;
    }
    else {
        $sc_error_message_html =~ s/\[\[errormessage\]\]/$plz_use_whole_numbers/;
        print $sc_error_message_html;
    }
    StoreFooter();
    $sc_bad_order_note_alt = q{};
    call_exit();

}


#######################################################################
#                   PrintNoHitsBodyHTML Subroutine
#######################################################################
# PrintNoHitsBodyHTML is utilized to produce an error message in case no
# hits were found based on the client-defined keywords or product searches
# It is called with no arguments and the following syntax:
#
# PrintNoHitsBodyHTML();

sub PrintNoHitsBodyHTML {
    $sc_header_status = '404 Not Found';
    &print_agora_http_headers();
    standard_page_header("$no_search_entries");
    if ( $sc_test_data_to_print && $sc_print_test_data eq 'yes' ) {
        print $sc_test_data_to_print;
    }
    StoreHeader();
    $sc_404_error_html =~ s/\[\[errormessage\]\]/$sc_search_error_message/;
    print $sc_404_error_html;
    StoreFooter();
}


#######################################################################
#                   PrintInvalidPageExtension Subroutine
#######################################################################

sub PrintInvalidPageExtension {
    package main;
    require_supporting_libraries( __FILE__, __LINE__,
        './system66/view/widgets_agorascript.pl',
        "$sc_html_setup_file_path");
    $sc_header_status = '405 Not Allowed';
    print_agora_http_headers();
    standard_page_header("$sc_header_status");
    StoreHeader();
    $sc_405_error_html =~ s/\[\[errormessage1\]\]/$agora_error_notice_title01/;
    $sc_405_error_html =~ s/\[\[errormessage2\]\]/$sc_page_load_security_warning/;
    print $sc_405_error_html . '</div>';
    StoreFooter();
}


#######################################################################
#                   PrintNoRemotePages Subroutine
#######################################################################

sub PrintNoRemotePages {
    package main;
    require_supporting_libraries( __FILE__, __LINE__,
        './system66/view/widgets_agorascript.pl',
        "$sc_html_setup_file_path");
    $sc_header_status = '405 Not Allowed';
    &print_agora_http_headers();
    standard_page_header("$sc_header_status");
    StoreHeader();
    $sc_405_error_html =~ s/\[\[errormessage1\]\]/$agora_error_notice_title01/;
    $sc_405_error_html =~ s/\[\[errormessage2\]\]/$agora_error_try_nav_outside/;
    print $sc_405_error_html . '</div>';
    StoreFooter();
}


#######################################################################
#                   checkoutFormMissing Subroutine
#######################################################################

# if no order form is set or the file has been removed, we assume checkout
# has been purposely disabled.

sub checkoutFormMissing {
    standard_page_header("$agora_error_pagetitle");
    StoreHeader();
    $sc_error_message_html =~ s/\[\[errormessage\]\]/$agora_error_orderform_disabled/;
    print '<p><br></p><p><b>' . $sc_error_message_html . '</b></p>';
    StoreFooter();
}

########################################################################

1;
