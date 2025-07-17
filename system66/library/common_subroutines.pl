$versions{'common_subroutines.pl'} = '06.6.00.0000';

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
#######################################################################


#########################################################################
# For running codehooks at various places
#########################################################################

sub codehook {
    local ($hookname) = @_;
    local ( $codehook, $err_code, @hooklist );
    if ( $codehooks{$hookname} ) {
        @hooklist = split( /\|/, $codehooks{$hookname} );
        foreach $codehook (@hooklist) {
            eval("&$codehook;");
            $err_code = $@;
            if ( $err_code ) {    #script died, error of some kind
                update_error_log( "code-hook $hookname $codehook $err_code", '', '' );
            }
        }
    }
}

#########################################################################
# For adding codehook code (for later execution) to embedded codehooks
#########################################################################

sub add_codehook {
    local ( $hookname, $sub_name ) = @_;
    local ( $codehook, $err_code, @hooklist );
    if ( $sub_name eq '' ) { return; }
    @hooklist = split( /\|/, $codehooks{$hookname} );
    foreach $codehook (@hooklist) {
        if ( $codehook eq $sub_name ) {    # already on the list, no need to add
            return;
        }
    }
    if ( $codehooks{$hookname} eq '' ) {
        $codehooks{$hookname} = $sub_name;
    }
    else {
        $codehooks{$hookname} .= '|' . $sub_name;
    }
}

#########################################################################

sub replace_codehook {    # replace ALL hooks with the value provided
    local ( $hookname, $sub_name ) = @_;
    $codehooks{$hookname} = $sub_name;
}


#########################################################################

#
#
#
#
#

#########################################################################
# To run free form logic entered in manager settings or a loaded file
#########################################################################

sub run_freeform_logic {
  local($f)=__FILE__;
  local($l)=__LINE__;
  if ($sc_free_form_logic_done) {return '';}
  $sc_free_form_logic_done = 1;
  eval($sc_free_form_logic);
  if ($@ ne "") {
    update_error_log("Free Form Logic err: $@",$f,$l);
    open(ERROR, $error_page);
    while (<ERROR>) { print $_; }
    close (ERROR);
    call_exit();
   }
}

#########################################################################

sub run_freeform_logic_too {
  local($f)=__FILE__;
  local($l)=__LINE__;
  eval($sc_free_form_logic_too);
  if ($@ ne "") {
    update_error_log("Free Form Too Logic err: $@",$f,$l);
    open(ERROR, $error_page);
    while (<ERROR>) { print $_; }
    close (ERROR);
    call_exit();
   }
}

#########################################################################

sub eval_custom_logic {
    my ( $logic, $whoami, $file, $line ) = @_;
    my ( $err_code, $result ) = q{};

    if ( $logic ) {
        $result   = eval($logic);
        $err_code = $@;
        if ( $err_code ) {    #script died, error of some kind
            update_error_log( "$whoami $err_code ", $file, $line );
            $result = q{};
        }
    }

    return $result;
}

#########################################################################

#
#
#
#
#

#########################################################################
#     check if a form_data button has been selected
#########################################################################

# not for forms but for form_data hashes/variables.
sub form_check {
    local ($name)  = @_;
    local ($name2) = $name . '.x';

    if ( ( $form_data{$name} ) || ( $form_data{$name2} ) ) {
        return 1;
    }
    else {
        return '';
    }
}

#########################################################################

#
#
#
#
#

#########################################################################

sub swapCookieFormData {
    my $val = shift;

    if ( ( $form_data{$val} eq '' ) && $cookie{$val} ) {
        $form_data{$val} = $cookie{$val};
    }
    elsif ( $form_data{$val} && ( $cookie{$val} eq '' ) ) {
        $cookie{$val} = $form_data{$val};
    }

}

#########################################################################

#
#
#
#
#

#########################################################################

sub checkReferrer {

    # BEGIN REPEATED PAGE LOADING TEST
    # referer check taken out in 4.0L
    local ( $test_repeat, $raw_text );

    $test_repeat = 0;
    if ($sc_test_for_store_cart_change_repeats) {
        $test_repeat = $sc_test_repeat;
    }

    if ( get_agora('SSI_REDIRECT_OK') ) {
        set_agora( 'SSI_REDIRECT_OK', '' );
        $referringDomain = $acceptedDomain;
    }

    if ($test_repeat) {
        if ( $sc_repeat_fake_it =~ /yes/i ) {
            repeat_fake_it();
        }
        else {
            $special_message = $messages{'chkref_01'};
            display_cart_contents();
        }
    }

}

#########################################################################

sub repeat_fake_it {
    if ( $form_data{'add_to_cart_button.x'} ) {
        finish_add_to_the_cart();
        call_exit();
    }
    elsif ( $form_data{'submit_change_quantity_button.x'} ) {
        finish_modify_quantity_of_items_in_cart();
        call_exit();
    }
    elsif ( $form_data{'submit_deletion_button.x'} ) {
        finish_delete_from_cart();
        call_exit();
    }
    else {
        $special_message = $messages{'chkref_01'};
        display_cart_contents();
    }
    return;
}

#########################################################################

#
#
#
#
#

#######################################################################

sub set_agora {
    my ( $inx, $val ) = @_;
    if ( $val eq '' ) {
        delete( $agora{$inx} );
    }
    else {
        $agora{$inx} = $val;
    }
    return $val;
}

#######################################################################

sub get_agora {
    my ($inx) = @_;
    return $agora{$inx};
}

#######################################################################

#
#
#
#
#

#########################################################################
#     Check to see if data is numeric
#########################################################################

sub is_numeric() {
    my ($str) = shift;
    if ( $str =~ /^[0-9]{1,50}.?[0-9]{0,50}$/ ) {
        return (1);
    }
    else {
        return (0);
    }
}

#########################################################################
#     Encode URL string
#########################################################################

sub urlencode {
    my ($esc) = @_;
    $esc =~ s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
    $esc =~ s/ /+/g;
    return $esc;
}


sub trim() {
    local ($_) = @_;
    s/[\r\n\t]//gs;
    s/^\s+|\s+$//gs;
    return $_;
}

#########################################################################

#
#
#
#
#

#########################################################################

sub str_encode {    # encode a string for cgi or other purposes
    my ($str)   = @_;
    my ($mypat) = '[\x00-\x1F"\x27#%/+;<>?\x7F-\xFF]';
    $str =~ s/($mypat)/sprintf("%%%02x",unpack('c',$1))/ge;
    $str =~ tr/ /+/;
    return $str;
}

#########################################################################

sub str_decode {    # decode a string for cgi or other purposes
    my ($str) = @_;
    $str =~ tr/+/ /;
    $str =~ s/%(..)/pack("c",hex($1))/ge;
    return $str;
}

#########################################################################

#
#
#
#
#

#########################################################################

sub load_file_lines_to_str {    # load a text file
    my ($location) = @_;
    my (@lines)    = q{};
    open( XX_FILE, "<$location" );
    @lines = <XX_FILE>;
    close(XX_FILE);
    return join( '', @lines );
}

#########################################################################

sub load_file_to_str {          # load a file in binary mode
    my ($location) = @_;
    my ($content)  = q{};
    open( XX_FILE, "<$location" );
    binmode(XX_FILE);
    local $/ = undef;
    $contents = <XX_FILE>;
    close(XX_FILE);
    return $content;
}

#########################################################################

#
#
#
#
#

#########################################################################

sub debugGetFormKeysValues {

    my $text = q{};
    my $inx = q{};

    if ( ( $sc_debug_mode eq 'yes' ) && ( $sc_debug_form_data_values eq 'yes' ) ) {
        foreach $inx ( sort( keys %form_data ) ) {
            $text .= "  \$form_data{'$inx'} = $form_data{$inx}|";
        }
    }
    else { $text = 'null|'}

    return $text;
}

#########################################################################

#
#
#
#
#

#########################################################################
#                          get_file_lock
#########################################################################
#
# get_file_lock is a subroutine used to create a lockfile.
# Lockfiles are used to make sure that no more than one
# instance of the script can modify a file at one time.  A
# lock file is vital to the integrity of your data.
# Imagine what would happen if two or three people
# were using the same script to modify a shared file (like
# the error log) and each accessed the file at the same
# time.  At best, the data entered by some of the users
# would be lost.  Worse, the conflicting demands could
# possibly result in the corruption of the file.
#
# Thus, it is crucial to provide a way to monitor and
# control access to the file.  This is the goal of the
# lock file routines.  When an instance of this script
# tries to  access a shared file, it must first check for
# the existence of a lock file by using the file lock
# checks in get_file_lock.
#
# If get_file_lock determines that there is an existing
# lock file, it instructs the instance that called it to
# wait until the lock file disappears.  The script then
# waits and checks back after some time interval.  If the
# lock file still remains, it continues to wait until some
# point at which the admin has given it permissions to just
# overwrite the file because some other error must have
# occurred.
#
# If, on the other hand, the lock file has disappeared,
# the script asks get_file_lock to create a new lock file
# and then goes ahead and edits the file.
#
# The subroutine takes one argument, the name to use for
# the lock file and is called with the following syntax:
#
# &get_file_lock("file.name");
#
#########################################################################

sub get_file_lock {

    local ($lock_file) = shift;
    local ($endtime);
    local ($exit_get_file_lock) = '';
    my $sleep = 0;
    my $endtime = 21; # was 20 originally

    codehook( 'get_file_lock' );

    if ( $exit_get_file_lock ) { return; }

    # If the lockfile has not been removed by the time is up, there must be
    # some other problem with the file system.  Perhaps an instance of
    # the script crashed and never could delete the lock file.
    while ( -e $lock_file && $sleep < $endtime ) {
        sleep(1);
        $sleep++;
    }

    if ( $sc_use_flock_file_lock ne 'yes') {
        open( LOCK_FILE, ">$lock_file" )
          || file_open_error("$lock_file", "$agora_error_lockfile01", __FILE__, __LINE__);
    }

    # Note: If flock is available on your system, feel free to
    # use it.  flock is an even safer method of locking your
    # file because it locks it at the system level.  The above
    # routine is "pretty good" and it will serve for most
    # systems.
    else {
        flock(LOCK_FILE, 2); # 2 exclusively locks the file
    }
}

#########################################################################
#                          release_file_lock
#########################################################################
#
# release_file_lock is the partner of get_file_lock.  When
# an instance of this script is done using the file it
# needs to manipulate, it calls release_file_lock to
# delete the lock file that it put in place so that other
# instances of the script can get to the shared file.  It
# takes one argument, the name of the lock file, and is
# called with the following syntax:
#
# release_file_lock("file.name");
#
#########################################################################

sub release_file_lock {
    local ($lock_file)    = @_;
    local ($exit_release_file_lock) = '';

    codehook( 'release_file_lock' );

    if ( $exit_release_file_lock ) { return; }

    if ( $sc_use_flock_file_lock eq 'yes') {
        flock(LOCK_FILE, 8); # 8 unlocks the file
    }

    # As we mentioned in the discussion of get_file_lock,
    # flock is a superior file locking system.  If your system
    # has it, go ahead and use it instead of this version.
    else {
        close(LOCK_FILE);
        unlink($lock_file);
    }
}

#########################################################################

#
#
#
#
#

#########################################################################
# For clean up purposes such as closing files, removing locks, etc.
#########################################################################

sub my_die {
    local ($msg) = @_;
    if ( $sc_in_throes_of_death eq $sc_yes ) { die $msg; }
    $sc_in_throes_of_death = 'yes';
    call_exit();
    die $msg;
}

#########################################################################

sub call_exit {
    #require_supporting_libraries( __FILE__, __LINE__,"$sc_html_setup_file_path" );
    codehook( 'cleanup_before_exit' );
    if ( $sc_in_throes_of_death ne 'yes' ) {
        exit;
    }
}

#########################################################################

1;
