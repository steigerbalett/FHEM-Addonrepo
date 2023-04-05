
# $Id: 36_PCA301.pm 12056 2020-07-12 13:00:00Z Ralf9 $
#
# 2016 justme1968
#
# 2020 Anpassungen und Erweiterungen von Ralf9

package main;

use strict;
use warnings;
use SetExtensions;

use constant {
	PCA301_send_OnOffStatus_timeout  => 2,	# Wartezeit bis ein sendRetry gemacht wird
};

#sub PCA301_Parse($$);
#sub PCA301_Send($$@);

my %PCA301_cmdtxt = (
	'5:0' => 'off',
	'5:1' => 'on',
	'4:0' => 'statreq',
	'4:1' => 'reset',
	'6:0' => 'identify',
	'17:0' => 'pairing'
	);

sub
PCA301_Initialize
{
  my ($hash) = @_;

  $hash->{Match}     = '^\\S+\\s+24';
  $hash->{SetFn}     = \&PCA301_Set;
  #$hash->{GetFn}     = "PCA301_Get";
  $hash->{DefFn}     = \&PCA301_Define;
  $hash->{UndefFn}   = \&PCA301_Undef;
  $hash->{FingerprintFn}   = \&PCA301_Fingerprint;
  $hash->{ParseFn}   = \&PCA301_Parse;
  $hash->{AttrFn}    = \&PCA301_Attr;
  $hash->{AttrList}  = 'IODev'
                       .' ignore:1,0'
                       .' readonly:1,0'
                       .' forceOn:1,0'
                       .' offLevel'
                       .' pollingStatus'  # nur fuer SIGNALduino
                       .' sendMaxRetry'   # nur fuer SIGNALduino
                       ." $readingFnAttributes";
}

sub
PCA301_Define
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  if(@a != 4 ) {
    my $msg = 'wrong syntax: define <name> PCA301 <addr> <channel>';
    Log3 undef, 2, $msg;
    return $msg;
  }

  $a[2] =~ m/^([\da-f]{6})$/i;
  return "$a[2] is not a valid PCA301 address" if( !defined($1) );

  $a[3] =~ m/^([\da-f]{2})$/i;
  return "$a[3] is not a valid PCA301 channel" if( !defined($1) );

  my $name = $a[0];
  my $addr = $a[2];
  my $channel = $a[3];

  #return "$addr is not a 1 byte hex value" if( $addr !~ /^[\da-f]{2}$/i );
  #return "$addr is not an allowed address" if( $addr eq "00" );

  return "PCA301 device $addr already used for $modules{PCA301}{defptr}{$addr}->{NAME}." if( $modules{PCA301}{defptr}{$addr}
                                                                                             && $modules{PCA301}{defptr}{$addr}->{NAME} ne $name );

  $hash->{addr} = $addr;
  $hash->{channel} = $channel;

  $modules{PCA301}{defptr}{$addr} = $hash;

  AssignIoPort($hash);
  if(defined($hash->{IODev}->{NAME})) {
    Log3 $name, 3, "$name: I/O device is " . $hash->{IODev}->{NAME};
  } else {
    Log3 $name, 1, "$name: no I/O device";
  }

  $attr{$name}{devStateIcon} = 'on:on:toggle off:off:toggle set.*:light_exclamation:off' if( !defined( $attr{$name}{devStateIcon} ) );
  $attr{$name}{webCmd} = 'on:off:toggle:statusRequest' if( !defined( $attr{$name}{webCmd} ) );
  CommandAttr( undef, "$name userReadings consumptionTotal:consumption.* monotonic {ReadingsVal(\$name,'consumption',0)}" ) if( !defined( $attr{$name}{userReadings} ) );

  #PCA301_Send($hash, $addr, "00" );

  return;
}

#####################################
sub
PCA301_Undef
{
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};
  my $addr = $hash->{addr};

  delete( $modules{PCA301}{defptr}{$addr} );

  return;
}

#####################################
### command: 0x04=measure data, 0x05=switch device, 0x06=device LED, 0x11=pairing
#####################################
sub
PCA301_Set
{
  my ($hash, $name, @aa) = @_;

  my $cnt = @aa;

  return "\"set $name\" needs at least one parameter" if($cnt < 1);

  my $cmd = $aa[0];
  my $arg = $aa[1];
  my $arg2 = $aa[2];
  my $arg3 = $aa[3];

  my $readonly = AttrVal($name, 'readonly', '0' );
  my $io = $hash->{IODev};
  
  my $list = 'identify:noArg reset:noArg statusRequest:noArg';
  #$list .= ' CmdData'  if( !$readonly );	# nur fuer Test und Debug zwecke
  $list .= ' off:noArg on:noArg toggle:noArg' if( !$readonly );
  $list .= ' pairing:noArg' if (!$readonly && $io->{TYPE} eq 'SIGNALduino');

  if( $cmd eq 'toggle' ) {
    $cmd = ReadingsVal($name,'state','on') eq 'off' ? 'on' :'off';
  }

  if( !$readonly && $cmd eq 'off' ) {
    readingsSingleUpdate($hash, 'state', "set-$cmd", 1);
    PCA301_Send( $hash, '5:0', 1 );
  } elsif( !$readonly && $cmd eq 'on' ) {
    readingsSingleUpdate($hash, 'state', "set-$cmd", 1);
    PCA301_Send( $hash, '5:1', 1 );
  } elsif( $cmd eq 'statusRequest' ) {
    readingsSingleUpdate($hash, 'state', "set-$cmd", 1);
    PCA301_Send( $hash, '4:0', 1 );
  } elsif( $cmd eq 'reset' ) {
    readingsSingleUpdate($hash, 'state', "set-$cmd", 1);
    PCA301_Send( $hash, '4:1', 0 );
  } elsif( $cmd eq 'identify' ) {
    PCA301_Send( $hash, '6:0', 0 );
  } elsif( !$readonly && $cmd eq 'pairing' ) {	# nur fuer SIGNALduino
    PCA301_Send( $hash, '17:0', 0 );
  } elsif( !$readonly && $cmd eq 'CmdData' ) {	# nur fuer Test und Debug zwecke
    PCA301_Send( $hash, $arg, 0 );
  } else {
    return SetExtensions($hash, $list, $name, @aa);
  }

  return;
}

#####################################
sub
PCA301_Get
{
  my ($hash, $name, $cmd, @args) = @_;

  return "\"get $name\" needs at least one parameter" if(@_ < 3);

  my $list = "";

  return "Unknown argument $cmd, choose one of $list";
}

sub
PCA301_Fingerprint
{
  my ($name, $msg) = @_;

  return ( "", $msg );
}

sub
PCA301_ForceOn
{
  my ($hash) = @_;

  PCA301_Send( $hash, '5:1', 1 );
}

sub
PCA301_Poll_statusRequest
{
  my ($param) = @_;
  my (undef,$name) = split(':', $param);
  my $hash = $defs{$name};
  
  readingsSingleUpdate($hash, 'state', 'set-statusRequest', 1);
  PCA301_Send( $hash, '4:0', 1 );
  $hash->{cmd} = '4:0';
  InternalTimer(gettimeofday()+PCA301_send_OnOffStatus_timeout, 'PCA301_SendRetry', $hash, 0);
  if ($hash->{pollStatus}) {
    InternalTimer(gettimeofday() + $hash->{pollStatus}, 'PCA301_Poll_statusRequest', "Poll_statusRequest:$name");
  }
}

sub
PCA301_SendRetry
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $retrycmd = $hash->{cmd};
	
	RemoveInternalTimer($hash);
	
	my $sendMaxCmdRetry = AttrVal($name, 'sendMaxRetry', '3');
	
	if (!defined($hash->{cmdRetry})) {
		$hash->{cmdRetry} = 1;
	} else {
		$hash->{cmdRetry}++;
	}
	Log3 $hash, 3, "$name: PCA301_SendRetry: $hash->{cmdRetry} cmd=$PCA301_cmdtxt{$retrycmd}";
	PCA301_Send( $hash, $retrycmd, 0);
	if ($hash->{cmdRetry} <= $sendMaxCmdRetry) {
		InternalTimer(gettimeofday() + PCA301_send_OnOffStatus_timeout, 'PCA301_SendRetry', $hash, 0);
	}
	else {
		delete ($hash->{cmdRetry});
	}
}

sub
PCA301_Parse
{
  my ($hash, $msg) = @_;
  my $name = $hash->{NAME};

  #return undef if( $msg !~ m/^[\dA-F]{12,}$/ );

  if( $msg =~ m/^L/ ) {
    my @parts = split( ' ', substr($msg, 5), 4 );
    $msg = "OK 24 $parts[3]";
  }

  my( @bytes, $channel,$cmd,$addr,$data,$power,$consumption );
  if( $msg =~ m/^OK/ ) {
    @bytes = split( ' ', substr($msg, 6) );

    $channel = sprintf( "%02X", $bytes[0] );
    $cmd = $bytes[1];
    $addr = sprintf( "%02X%02X%02X", $bytes[2], $bytes[3], $bytes[4] );
    $data = $bytes[5];
    return "" if( $cmd == 0x04 && $bytes[6] == 170 && $bytes[7] == 170 && $bytes[8] == 170 && $bytes[9] == 170 ); # ignore commands from display unit
    return "" if( $cmd == 0x05 && ( $bytes[6] != 170 || $bytes[7] != 170 || $bytes[8] != 170 || $bytes[9] != 170 ) ); # ignore commands not from the plug
  } elsif ( $msg =~ m/^TX/ ) {
    # ignore TX
    return "";
  } else {
    DoTrigger($name, "UNKNOWNCODE $msg");
    Log3 $name, 3, "$name: Unknown code $msg, help me!";
    return "";
  }

  my $raddr = $addr;
  my $rhash = $modules{PCA301}{defptr}{$raddr};
  my $rname = $rhash?$rhash->{NAME}:$raddr;

  return "" if( IsIgnored($rname) );

   if( !$modules{PCA301}{defptr}{$raddr} ) {
     Log3 $name, 3, "PCA301 Unknown device $rname, please define it";

     return "UNDEFINED PCA301_$rname PCA301 $raddr $channel";
   }

  #CommandAttr( undef, "$rname userReadings consumptionTotal:consumption.* monotonic {ReadingsVal($rname,'consumption',0)}" ) if( !defined( $attr{$rname}{userReadings} ) );

  my @list;
  push(@list, $rname);

  $rhash->{PCA301_lastRcv} = TimeNow();

  if ($hash->{TYPE} ne 'SIGNALduino') {
    if( $rhash->{channel} ne $channel ) {
      Log3 $rname, 3, "PCA301 $rname, channel changed from $rhash->{channel} to $channel";

      $rhash->{channel} = $channel;
      $rhash->{DEF} = "$rhash->{addr} $rhash->{channel}";
      CommandSave(undef,undef) if( AttrVal( 'autocreate', 'autosave', 1 ) );
    }
  }
  else {	# SIGNALduino
    RemoveInternalTimer($rhash);
    delete ($rhash->{cmdRetry});
  }

  my $readonly = AttrVal($rname, 'readonly', '0' );
  my $state = "";

  if( $cmd eq 0x04 ) {
    if (defined($rhash->{cmd})) {
      delete($rhash->{cmd});
    }
    $state = $data==0x00?'off':'on';
    my $power = ($bytes[6]*256 + $bytes[7]) / 10.0;
    my $consumption = ($bytes[8]*256 + $bytes[9]) / 100.0;
    $state = $power if( $readonly );
    my $off_level = AttrVal($rname, 'offLevel', undef);
    $state = 'off' if( $readonly && defined($off_level) && $power <= $off_level );
    Log3 $rhash, 4, "$name: PCA301 Parse: $rname, state=$state, power=$power";
    readingsBeginUpdate($rhash);
    readingsBulkUpdate($rhash, 'power', $power) if( $power != ReadingsVal($rname,'power',0) );
    readingsBulkUpdate($rhash, 'consumption', $consumption) if( $consumption != ReadingsVal($rname,'consumption',0) );
    readingsBulkUpdate($rhash, 'state', $state) if( $state ne ReadingsVal($rname,'state','') );
    readingsEndUpdate($rhash,1);
  } elsif( $cmd eq 0x05 ) {		# on / off
    if (defined($rhash->{cmd})) {
      delete($rhash->{cmd});
      $state = $data==0x00?"off":"on";	# Rueckmeldung von set on / off
    } else {
      $state = $data==0x00?'on':'off';	# on/off mit der Taste an der PCA301
    }
    readingsSingleUpdate($rhash, 'state', $state, 1);
  }
  if ($hash->{TYPE} eq 'SIGNALduino') {
    if ($state ne 'off' && !defined($rhash->{pollStatus})) {	# start polling statusRequest, falls noch nicht gestartet
      my $pollStat = AttrVal($rname, 'pollingStatus', '0' );
      my ($poll, $pollStatusOff) = split(":", $pollStat);
      if ($poll > 0) {
        if (defined($pollStatusOff) && $pollStatusOff == 0) {	# bei off das polling statusRequest stoppen?
          $rhash->{pollStatusOff} = $pollStatusOff;
        }
        Log3 $rhash, 3, "$rname: PCA301 Parse: start polling from statusRequest all $pollStat seconds";
        readingsSingleUpdate($rhash, 'pollingStatus', 'activated', 0);
        $rhash->{pollStatus} = $poll;
        InternalTimer(gettimeofday() + $poll, 'PCA301_Poll_statusRequest', "Poll_statusRequest:$rname");
      }
    }
    elsif ($state eq 'off' && exists($rhash->{pollStatus}) && defined($rhash->{pollStatusOff}) && $rhash->{pollStatusOff} == 0) {
      delete($rhash->{pollStatus});
      delete($rhash->{pollStatusOff});
      RemoveInternalTimer("Poll_statusRequest:$rname");
      Log3 $rhash, 3, "$rname: PCA301 Parse: stop polling from statusRequest";
      readingsSingleUpdate($rhash, 'pollingStatus', 'stopped', 0);
    }
  }

  if( AttrVal($rname, 'forceOn', 0 ) == 1
      && $state eq 'off'  ) {
    readingsSingleUpdate($rhash, 'state', 'set-forceOn', 1);
    InternalTimer(gettimeofday()+3, 'PCA301_ForceOn', $rhash, 0);
  }

  return @list;
}

sub
PCA301_CalculateCRC16
{
	my ($dmsg,$poly) = @_;
	my $len = length($dmsg);
	my $i;
	my $byte;
	my $crc16 = 0;
	
	for ($i=0; $i<$len; $i+=2) {
		$byte = hex(substr($dmsg,$i,2)) * 0x100;	# in 16 Bit wandeln
		for (0..7)	# 8 Bits pro Byte
		{
			#if (($byte & 0x8000) ^ ($crc16 & 0x8000)) {
			if (($byte ^ $crc16) & 0x8000) {
				$crc16 <<= 1;
				$crc16 ^= $poly;
			} else {
				$crc16 <<= 1;
			}
			$crc16 &= 0xFFFF;
			$byte <<= 1;
			$byte &= 0xFFFF;
		}
	}
	return $crc16;
}

sub
PCA301_Send
{
  my ($hash, $cmdtxt, $sendRetry) = @_;     # $sendRetry = 1  -> PCA301_SendRetry wird aufgerufen
  my ($cmd, $data) = split(':', $cmdtxt);
  my $io = $hash->{IODev};
  my $msg;
  my $cmdStr = "";

  if (exists($PCA301_cmdtxt{$cmdtxt})) {
     $cmdStr = $PCA301_cmdtxt{$cmdtxt};
  }

  $hash->{PCA301_lastSend} = TimeNow();

  if ($io->{TYPE} ne 'SIGNALduino') {
     $msg = sprintf( "%i,%i,%i,%i,%i,%i,255,255,255,255s", hex($hash->{channel}),
                                                           $cmd,
                                                           hex(substr($hash->{addr},0,2)), hex(substr($hash->{addr},2,2)), hex(substr($hash->{addr},4,2)),
                                                           $data );
    Log3 $hash, 4, $hash->{NAME} . ": PCA301 send $cmdStr: msg=$msg";
    
    IOWrite( $hash, $msg );
  }		# SIGNALduino
  else {
    if ($io->{DevState} ne 'initialized') {
      Log3 $hash, 3, $hash->{NAME} . ': PCA301 not send, ' . $io->{NAME} . ' is not initialized';
      return;
    }
    $msg = sprintf("%02X%02X%s%02X", hex($hash->{channel}), $cmd, $hash->{addr}, $data);
    $msg .= 'FFFFFFFF';
    my $crc16 = sprintf("%04X", PCA301_CalculateCRC16($msg, 0x8005));
    $msg = "SN;N=3;D=$msg$crc16" . 'AAAAAA;';
    Log3 $hash, 3, $hash->{NAME} . ": PCA301 send $cmdStr: msg=$msg";
    
    IOWrite($hash, 'raw', $msg);
    
    if ($sendRetry) {
      $hash->{cmd} = $cmdtxt;
      InternalTimer(gettimeofday()+PCA301_send_OnOffStatus_timeout, 'PCA301_SendRetry', $hash, 0);
    }
  }
}

sub
PCA301_Attr
{
  my ($cmd, $name, $attrName, $attrVal) = @_;
  
  my $hash = $defs{$name};
  my $io = $hash->{IODev};
  if ($attrName eq 'pollingStatus' && $io->{TYPE} eq 'SIGNALduino') {
    my $pollStat;
    if (!defined($attrVal)) {
      $pollStat = 0;
    }
    else {
      ($pollStat, undef) = split(":", $attrVal)
    }
    #Log3 $name, 3, "PCA301: attrName=$attrName attrVal=$attrVal";
    if ($pollStat < 30 && $pollStat > 0) {
      return 'value too small (min 30)';
    }
    if ($pollStat == 0) {	# stop polling statusRequest
       my $hash = $defs{$name};
       delete($hash->{pollStatus});
       delete($hash->{pollStatusOff});
       RemoveInternalTimer("Poll_statusRequest:$name");
       Log3 $hash, 3, "$name: PCA301 Parse: stop polling from statusRequest";
       readingsSingleUpdate($hash, 'pollingStatus', 'stopped', 0);
    }
  }
  return;
}

1;

=pod
=item summary    PCA301 devices
=item summary_DE PCA301 Ger&auml;te
=begin html

<a name="PCA301"></a>
<h3>PCA301</h3>
<ul>
  The PCA301 is a RF controlled AC mains plug with integrated power meter functionality from ELV.<br><br>

  It can be integrated in to FHEM via a <a href="#JeeLink">JeeLink</a> as the IODevice.<br><br>

  The JeeNode sketch required for this module can be found in .../contrib/arduino/36_PCA301-pcaSerial.zip.<br><br>

  <a name="PCA301Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; PCA301 &lt;addr&gt; &lt;channel&gt;</code> <br>
    <br>
    addr is a 6 digit hex number to identify the PCA301 device.
    channel is a 2 digit hex number to identify the PCA301 device.<br><br>
    Note: devices are autocreated on reception of the first message.<br>
  </ul>
  <br>

  <a name="PCA301_Set"></a>
  <b>Set</b>
  <ul>
    <li>on</li>
    <li>off</li>
    <li>identify<br>
      Blink the status led for ~5 seconds.</li>
    <li>reset<br>
      Reset consumption counters</li>
    <li>statusRequest<br>
      Request device status update.</li>
    <li>pairing<br>
      todo</li>
    <li><a href="#setExtensions"> set extensions</a> are supported.</li>
  </ul><br>

  <a name="PCA301_Get"></a>
  <b>Get</b>
  <ul>
  </ul><br>

  <a name="PCA301_Readings"></a>
  <b>Readings</b>
  <ul>
    <li>power</li>
    <li>consumption</li>
    <li>consumptionTotal<br>
      will be created as a default user reading to have a continous consumption value that is not influenced
      by the regualar reset or overflow of the normal consumption reading</li>
  </ul><br>

  <a name="PCA301_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li>pollStatus<br>
      if greater than 0 then send statusRequest all this value seconds.</li>
    <li>forceOn<br>
      try to switch on the device whenever an off status is received.</li>
    <li>offLevel<br>
      a power level less or equal <code>offLevel</code> is considered to be off. used only in conjunction with readonly.</li>
    <li>readonly<br>
      if set to a value != 0 all switching commands (on, off, toggle, ...) will be disabled.</li>
    <li>ignore<br>
      1 -> ignore this device.</li>
  </ul><br>
</ul>

=end html
=cut
