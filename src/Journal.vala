public class Journal {

  private string    _name        = "";
  private string    _template    = "";
  private string    _description = "";
  private Database? _db          = null;

  public string name {
    get {
      return( _name );
    }
    set {
      if( _name != value ) {
        var old_db = db_path();
        var new_db = db_path( value );
        if( rename_db( old_db, new_db ) ) {
          _name = value;
          _db   = new Database( db_path(), false );
        }
      }
    }
  }
  public string template {
    get {
      return( _template );
    }
    set {
      _template = value;
    }
  }
  public string description {
    get {
      return( _description );
    }
    set {
      _description = value;
    }
  }
  public Database? db {
    get {
      return( _db );
    }
  }
  public bool is_trash {
    get {
      return( _db.include_journal );
    }
  }

  /* Default constructor */
  public Journal( string name, string template, string description ) {
    _name        = name;
    _template    = template;
    _description = description;
    _db          = new Database( db_path(), false );
  }

  /* Constructor for trash */
  public Journal.trash() {
    _name = _( "Trash" );
    _db   = new Database( db_path(), true );
  }

  /* Constructor */
  public Journal.from_xml( Xml.Node* node, out bool loaded ) {
    loaded = load( node );
  }

  /* Gets the pathname of the associated database */
  private string db_path( string? n = null ) {
    var name = (n ?? _name).down().replace( " ", "-" );
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "db", name + ".db" ) );
  }

  /* Renames the database */
  private bool rename_db( string old_db, string new_db ) {
    return( FileUtils.rename( old_db, new_db ) == 0 );
  }

  /* This should be called when we are deleting this journal entry */
  public bool remove_db() {
    return( FileUtils.unlink( db_path() ) == 0 );
  }

  /* Moves the given entry from this journal to the given to_journal */
  public bool move_entry( DBEntry entry, Journal to_journal ) {
    return( to_journal.db.create_entry( entry ) &&
            to_journal.db.save_entry( entry ) &&
            db.remove_entry( entry ) );
  }

  /* Saves this journal in XML format */
  public Xml.Node* save() {

    Xml.Node* node = new Xml.Node( null, "journal" );

    node->set_prop( "name", _name );
    node->set_prop( "template", _template );
    node->set_prop( "description", _description );

    return( node );

  }

  /* Loads the journal from XML format */
  public bool load( Xml.Node* node ) {

    var n = node->get_prop( "name" );
    if( n != null ) {
      _name = n;
    }

    var t = node->get_prop( "template" );
    if( t != null ) {
      _template = t;
    }

    var d = node->get_prop( "description" );
    if( d != null ) {
      _description = d;
    }

    /* If the name was set and the database file exists, create the database */
    if( (_name != "") && FileUtils.test( db_path(), FileTest.EXISTS ) ) {
      _db = new Database( db_path(), false );
      return( true );
    }

    return( false );

  }

}
