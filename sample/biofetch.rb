#!/usr/proj/bioruby/bin/ruby
#
# biofetch.rb : BioFetch server (interface to GenomeNet/DBGET via KEGG API)
#
#   Copyright (C) 2002-2004 KATAYAMA Toshiaki <k@bioruby.org>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#  $Id: biofetch.rb,v 1.9 2004/01/29 01:37:22 k Exp $
#

require 'cgi'
require 'html/template'
require 'bio/io/keggapi'

MAX_ID_NUM = 50

def print_text_page(str)
  print "Content-type: text/plain; charset=UTF-8\n\n"
  puts str
  exit
end

def error_1(db)
  str = "ERROR 1 Unknown database [#{db}]."
  print_text_page(str)
end

def error_2(style)
  str = "ERROR 2 Unknown style [#{style}]."
  print_text_page(str)
end

def error_3(format, db)
  str = "ERROR 3 Format [#{format}] not known for database [#{db}]."
  print_text_page(str)
end

def error_4(entry_id, db)
  str = "ERROR 4 ID [#{entry_id}] not found in database [#{db}]."
  print_text_page(str)
end

def error_5(count)
  str = "ERROR 5 Too many IDs [#{count}]. Max [#{MAX_ID_NUM}] allowed."
  print_text_page(str)
end

def error_6(info)
  str = "ERROR 6 Illegal information request [#{info}]."
  print_text_page(str)
end


def keggapi_dbinfo
  serv = Bio::KEGG::API.new
  serv.list_databases
end

def list_databases
  ary = []
  if dbinfo = keggapi_dbinfo
    dbinfo.each do |line|
      ary.push(line.split[1])
    end
  end
  return ary[3..-1]
end

def check_fasta_ok(db)
  # sequence databases supported by Bio::FlatFile.auto
  /genes|gb|genbank|genpept|rs|refseq|emb|sp|swiss|pir/.match(db)
end

def show_info_page(info, db)
  case info
  when /db/
    if db_list = list_databases
      str = db_list.sort.join(' ')
    else
      str = "Error: list_databases"
    end
    print_text_page(str)
  when /format/
    fasta = " fasta" if check_fasta_ok(db)
    str = "default#{fasta}"
    print_text_page(str)
  when /maxid/
    str = MAX_ID_NUM.to_s
    print_text_page(str)
  else
    error_6(info)
  end
end

def check_dbname(db)
  error_1(db) unless list_databases.include?(db)
end

def check_style(style)
  error_2(style) unless /html|raw/.match(style)
end

def check_format(format, db)
  error_3(format, db) if format && ! /fasta|default/.match(format)
end

def check_number_of_id(num)
  error_5(num) if num > MAX_ID_NUM
end

def goto_html_style_page(db, id_list, format)
  url = "http://www.genome.ad.jp/dbget-bin/www_bget"
  opt = '-f+' if /fasta/.match(format)
  ids = id_list.join('%2B')
  print "Location: #{url}?#{opt}#{db}+#{ids}\n\n"
  exit
end

def convert_to_fasta_format(str, db)
  require 'bio'
  require 'stringio'

  fasta = Array.new

  entries = StringIO.new(str)
  Bio::FlatFile.auto(entries) do |ff|
    ff.each do |entry|
      seq = nil
      if entry.respond_to?(:seq)
        seq = entry.seq
      elsif entry.respond_to?(:aaseq)
        seq = entry.naseq
      elsif entry.respond_to?(:naseq)
        seq = entry.naseq
      end
      if seq
        entry_id   = entry.respond_to?(:entry_id)   ? entry.entry_id   : ''
        definition = entry.respond_to?(:definition) ? entry.definition : ''
        fasta << seq.to_fasta("#{db}:#{entry_id} #{definition}", 60)
      end
    end
  end

  return fasta.join
end

def keggapi_bget(db, id_list, format)
  serv = Bio::KEGG::API.new

  results = Array.new

  id_list.each do |query_id|
    entry_id = "#{db}:#{query_id}"
    if result = serv.get_entries(entry_id)
      results << result
    else
      error_4(query_id, db)
    end
  end

  if /fasta/.match(format)
    entries = convert_to_fasta_format(results.join, db)
  else
    entries = results.join
  end

  return entries
end

def show_result_page(db, id_list, style, format)
  check_style(style)
  check_format(format, db)
  check_number_of_id(id_list.length)
  check_dbname(db)

  if /html/.match(style)
    goto_html_style_page(db, id_list, format)
  end

  entries = keggapi_bget(db, id_list, format)
  print_text_page(entries)
end

begin
  cgi = CGI.new

  if cgi['info'].empty?
    if cgi['id'].empty?
      html = HTML::Template.new
      html.set_html(DATA.read)
      html.param('max_id_num' => MAX_ID_NUM)
      cgi.out do
        html.output
      end
    else
      db = cgi['db'].downcase
      id_list = cgi['id'].split(/\W/)		# not only ','
      style = cgi['style'].downcase
      format = cgi['format'].downcase
      show_result_page(db, id_list, style, format)
    end
  else
    db = cgi['db'].downcase
    info = cgi['info'].downcase
    show_info_page(info, db)
  end
end


=begin

This program was created during BioHackathon 2002, Tucson and updated
in Cape Town :)

Rewrited in 2004 to use KEGG API as the bioruby.org server left from Kyoto
University (where DBGET runs) and the old version could not run without
having internally accessible DBGET server.

=end


__END__

<HTML>
<HEAD>
  <TITLE>BioFetch interface to GenomeNet/DBGET</TITLE>
  <LINK href="http://bioruby.org/img/favicon.png" rel="icon" type="image/png">
  <LINK href="http://bioruby.org/css/bioruby.css" rel="stylesheet" type="text/css">
</HEAD>

<BODY bgcolor="#ffffff">

<H1>
<IMG src="http://bioruby.org/img/ruby.png" align="middle">
BioFetch interface to
<A href="http://www.genome.ad.jp/dbget/">GenomeNet/DBGET</A>
</H1>

<P>This page allows you to retrieve up to <!var:max_id_num> entries at the time from various up-to-date biological databases.</P>

<HR>

<FORM METHOD="post" ENCTYPE="application/x-www-form-urlencoded" action="biofetch.rb">

<SELECT name="db">
<OPTION value="genbank">GenBank</OPTION>
<OPTION value="refseq">RefSeq</OPTION>
<OPTION value="embl">EMBL</OPTION>
<OPTION value="swissprot">Swiss-Prot</OPTION>
<OPTION value="pir">PIR</OPTION>
<OPTION value="prf">PRF</OPTION>
<OPTION value="pdb">PDB</OPTION>
<OPTION value="pdbstr">PDBSTR</OPTION>
<OPTION value="epd">EPD</OPTION>
<OPTION value="transfac">TRANSFAC</OPTION>
<OPTION value="prosite">PROSITE</OPTION>
<OPTION value="pmd">PMD</OPTION>
<OPTION value="litdb">LITDB</OPTION>
<OPTION value="omim">OMIM</OPTION>
<OPTION value="ligand">KEGG/LIGAND</OPTION>
<OPTION value="pathway">KEGG/PATHWAY</OPTION>
<OPTION value="brite">KEGG/BRITE</OPTION>
<OPTION value="genes">KEGG/GENES</OPTION>
<OPTION value="genome">KEGG/GENOME</OPTION>
<OPTION value="linkdb">LinkDB</OPTION>
<OPTION value="aaindex">AAindex</OPTION>
</SELECT>

<INPUT name="id" size="40" type="text" maxlength="1000">

<SELECT name="format">
<OPTION value="default">Default</OPTION>
<OPTION value="fasta">Fasta</OPTION>
</SELECT>

<SELECT name="style">
<OPTION value="raw">Raw</OPTION>
<OPTION value="html">HTML</OPTION>
</SELECT>

<INPUT type="submit">

</FORM>

<HR>

<H2>Direct access</H2>

<P>http://bioruby.org/cgi-bin/biofetch.rb?format=(default|fasta|...);style=(html|raw);db=(genbank|embl|...);id=ID[,ID,ID,...]</P>
<P>(NOTE: the option separator ';' can be '&')</P>

<DL>
  <DT> <U>format</U> (optional)
  <DD> default|fasta|...

  <DT> <U>style</U> (required)
  <DD> html|raw

  <DT> <U>db</U> (required)
  <DD> genbank|refseq|embl|swissprot|pir|prf|pdb|pdbstr|epd|transfac|prosite|pmd|litdb|omim|ligand|pathway|brite|genes|genome|linkdb|aaindex|...

  <DT> <U>id</U> (required)
  <DD> comma separated list of IDs
</DL>

<P>See the <A href="http://obda.open-bio.org/">BioFetch specification</A> for more details.</P>

<H2>Server informations</H2>

<DL>
  <DT> <A href="?info=dbs">What databases are available?</A>
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?info=dbs

  <DT> <A href="?info=formats;db=embl">What formats does the database X have?</A>
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?info=formats;db=embl

  <DT> <A href="?info=maxids">How many entries can be retrieved simultaneously?</A>
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?info=maxids
</DL>

<H2>Examples</H2>

<DL>
  <DT> <A href="?format=default;style=raw;db=refseq;id=NC_000844">rs:NC_000844</A> (default/raw)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=default;style=raw;db=refseq;id=NC_000844

  <DT> <A href="?format=fasta;style=raw;db=refseq;id=NC_000844">rs:NC_000844</A> (fasta/raw)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=fasta;style=raw;db=refseq;id=NC_000844

  <DT> <A href="?format=default;style=html;db=refseq;id=NC_000844">rs:NC_000844</A> (default/html)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=default;style=html;db=refseq;id=NC_000844

  <DT> <A href="?format=default;style=raw;db=refseq;id=NC_000844,NC_000846">rs:NC_000844,NC_000846</A> (default/raw, multiple)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=default;style=raw;db=refseq;id=NC_000844,NC_000846

  <DT> <A href="?format=default;style=raw;db=embl;id=BUM">embl:BUM</A> (default/raw)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=default;style=raw;db=embl;id=BUM

  <DT> <A href="?format=default;style=raw;db=swissprot;id=CYC_BOVIN">sp:CYC_BOVIN</A> (default/raw)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=default;style=raw;db=swissprot;id=CYC_BOVIN

  <DT> <A href="?format=fasta;style=raw;db=swissprot;id=CYC_BOVIN">sp:CYC_BOVIN</A> (fasta/raw)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=fasta;style=raw;db=swissprot;id=CYC_BOVIN

  <DT> <A href="?format=default;style=raw;db=genes;id=b0015">genes:b0015</A> (default/raw)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=default;style=raw;db=genes;id=b0015

  <DT> <A href="?format=default;style=raw;db=prosite;id=PS00028">ps:PS00028</A> (default/raw)
  <DD> http://bioruby.org/cgi-bin/biofetch.rb?format=default;style=raw;db=prosite;id=PS00028
</DL>

<H2>Other BioFetch implementations</H2>

<UL>
  <LI> <A href="http://www.ebi.ac.uk/cgi-bin/dbfetch">dbfetch at EBI</A>
</UL>

<HR>

<DIV align=right>
<I>
staff@Bio<span class="ruby">Ruby</span>.org
</I>
<BR>
<BR>
<A href="http://bioruby.org/"><IMG border=0 src="/img/banner.gif"></A>
</DIV>

</BODY>
</HTML>
