/*
* Copyright (c) 2023 (https://github.com/phase1geo/Journaler)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gdk;

public class ExportXML : Export {

  public bool include_images { get; set; default = false; }
  public bool for_import     { get; set; default = false; }

  /* Constructor */
  public ExportXML() {
    base( "xml", _( "XML" ), {"xml"}, true, true );
  }

  /* Performs export to the given filename */
  public override bool export( string fname, Array<Journal> journals ) {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "journals" );

    for( int i=0; i<journals.length; i++ ) {
      root->add_child( export_journal( journals.index( i ), doc ) );
    }

    doc->set_root_element( root );
    doc->save_format_file( fname, 1 );

    delete doc;

    return( true );

  }

  /* Exports the contents of a single journal */
  private Xml.Node* export_journal( Journal journal, Xml.Doc* doc ) {

    Xml.Node* node = new Xml.Node( null, "journal" );
    Xml.Node* desc = new Xml.Node( null, "description" );
    Xml.Node* ents = new Xml.Node( null, "entries" );
    var entries    = new Array<DBEntry>();

    // Gather all of the stored entries from the database
    journal.db.get_all_entries( entries );

    node->set_prop( "name", journal.name );

    if( for_import ) {
      node->set_prop( "template", journal.template );
    }

    desc->set_content( journal.description );
    node->add_child( desc );

    for( int i=0; i<entries.length; i++ ) {
      ents->add_child( export_entry( journal, entries.index( i ), doc ) );
    }

    node->add_child( ents );

    return( node );

  }

  /* Exports the entry in XML format */
  private Xml.Node* export_entry( Journal journal, DBEntry entry, Xml.Doc* doc ) {

    Xml.Node* node = new Xml.Node( null, "entry" );

    var load_entry = new DBEntry();
    load_entry.date = entry.date;

    var result = journal.db.load_entry( load_entry, false );
    if( result == DBLoadResult.LOADED ) {

      node->set_prop( "title", load_entry.title );
      node->set_prop( "date",  load_entry.date );
      node->set_prop( "time",  load_entry.time );

      Xml.Node* text = new Xml.Node( null, "text" );
      text->add_child( doc->new_cdata_block( load_entry.text, load_entry.text.length ) );
      node->add_child( text );

      if( (entry.image != null) && false ) {

        var path = create_image( entry.image );

        if( path != null ) {

          Xml.Node* image = new Xml.Node( null, "image" );
          image->set_prop( "path", path );

          if( for_import ) {
            image->set_prop( "pos",  entry.image_pos.to_string() );
            image->set_prop( "vadj", entry.image_vadj.to_string() );
            image->set_prop( "hadj", entry.image_hadj.to_string() );
          }

          node->add_child( image );

        }

      }

      Xml.Node* tags = new Xml.Node( null, "tags" );

      foreach( var tag in entry.tags ) {
        Xml.Node* t = new Xml.Node( null, "tag" );
        t->set_prop( "name", tag );
        tags->add_child( t );
      }

      node->add_child( tags );

    }

    return( node );

  }

  /* Creates an image file from the given pixbuf and returns the pathname */
  private string? create_image( Pixbuf pixbuf ) {

    try {
      string fname = "";  // TBD
      if( pixbuf.save( fname, "png", "compression", "7" ) ) {
        return( fname );
      }
    } catch( Error e ) {}

    return( null );

  }

  // ----------------------------------------------------

  /* Imports given filename into drawing area */
  public override bool import( string fname, Journals journals, Journal? journal ) {

    Xml.Doc* doc = Xml.Parser.read_file( fname, null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return( false );
    }

    Xml.Node* root = doc->get_root_element();

    for( Xml.Node* it = root->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "journal") ) {
        import_journal( it, journals, journal );
      }
    }

    delete doc;

    return( true );

  }

  /* Imports a journal node */
  private void import_journal( Xml.Node* node, Journals journals, Journal? target ) {

    var name        = "";
    var template    = "";
    var description = "";
    var journal     = target;

    var n = node->get_prop( "name" );
    if( n != null ) {
      name = n;
      if( journal == null ) {
        journal = journals.get_journal_by_name( name );
      }
    } else {
      return;
    }

    var t = node->get_prop( "template" );
    if( t != null ) {
      template = t;
    }

    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        switch( it->name ) {
          case "description" :
            description = it->get_content();
            break;
          case "entries" :
            if( journal == null ) {
              journal = new Journal( name, template, description );
              journals.add_journal( journal, true );
            }
            import_entries( it, journal );
            break;
        }
      }
    }

  }

  private void import_entries( Xml.Node* node, Journal journal ) {

    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "entry") ) {
        import_entry( it, journal );
      }
    }

  }

  private void import_entry( Xml.Node* node, Journal journal ) {

    var entry = new DBEntry();

    var title = node->get_prop( "title" );
    if( title != null ) {
      entry.title = title;
    }

    var date = node->get_prop( "date" );
    if( date != null ) {
      entry.date = date;
    }

    var time = node->get_prop( "time" );
    if( time != null ) {
      entry.time = time;
    }

    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        switch( it->name ) {
          case "text"  :  import_text( it, entry );   break;
          case "image" :  import_image( it, entry );  break;
          case "tags"  :  import_tags( it, entry );   break;
        }
      }
    }

    var load_entry  = new DBEntry();
    load_entry.date = entry.date;

    var load_result = journal.db.load_entry( load_entry, true );
    if( load_result == DBLoadResult.LOADED ) {
      load_entry.merge_with_entry( entry );
      journal.db.save_entry( load_entry );
    } else if( load_result == DBLoadResult.CREATED ) {
      journal.db.save_entry( entry );
    }

  }

  /* Imports the specified text XML node */
  private void import_text( Xml.Node* node, DBEntry entry ) {

    Xml.Node* child = node->children;

    if( child->type == Xml.ElementType.CDATA_SECTION_NODE ) {
      entry.text = child->get_content();
    }

  }

  /* Imports the specified image XML node */
  private void import_image( Xml.Node* node, DBEntry entry ) {

    var path = node->get_prop( "path" );
    if( path != null ) {
      try {
        entry.image = new Pixbuf.from_file( path );
      } catch( Error e ) {}
    }

    var pos = node->get_prop( "pos" );
    if( pos != null ) {
      entry.image_pos = int.parse( pos );
    }

    var vadj = node->get_prop( "vadj" );
    if( vadj != null ) {
      entry.image_vadj = double.parse( vadj );
    }

    var hadj = node->get_prop( "hadj" );
    if( hadj != null ) {
      entry.image_hadj = double.parse( hadj );
    }

  }

  /* Imports the specified tags XML node */
  private void import_tags( Xml.Node* node, DBEntry entry ) {

    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "tag") ) {
        var tag = it->get_prop( "name" );
        if( tag != null ) {
          entry.add_tag( tag );
        }
      }
    }

  }

}


