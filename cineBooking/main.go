package main

import (
	"bufio"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"
    "go.etcd.io/bbolt"
	_ "github.com/lib/pq"
)


type Cliente struct {
	IDCliente       int    `json:"id_cliente"`
	Nombre          string `json:"nombre"`
	Apellido        string `json:"apellido"`
	DNI             int    `json:"dni"`
	FechaNacimiento string `json:"fecha_nacimiento"`
	Telefono        string `json:"telefono"`
	Email           string `json:"email"`
}

type Pelicula struct {
	ID       int    `json:"id_pelicula"`
	Titulo   string `json:"titulo"`
	Duracion string `json:"duracion"`
	Director string `json:"director"`
	Origen   string `json:"origen"`
	Formato  string `json:"formato"`
}

type SalaCine struct {
	IDSala            int    `json:"id_sala"`
	Nombre            string `json:"nombre"`
	Formato           string `json:"formato"`              
	NroFilas          int    `json:"nro_filas"`            
	NroButacasPorFila int    `json:"nro_butacas_por_fila"`
}

type OrdenPrueba struct {
    IDOrden     int    `json:"id_orden"`
    Operacion   string `json:"operacion"`
    // omitempty porque solo aparece en algunos jsons, por lo que lei es para omitirlo si esta vacio(veremos)
    IDSala      int    `json:"id_sala,omitempty"`
    FInicio     string `json:"f_inicio,omitempty"`
    IDPelicula  int    `json:"id_pelicula,omitempty"`
    IDFuncion   int    `json:"id_funcion,omitempty"`
    NroFila     int    `json:"nro_fila,omitempty"`
    NroButaca   int    `json:"nro_butaca,omitempty"`
    IDCliente   int    `json:"id_cliente,omitempty"`
}

func main() {
	connStr := "user=postgres dbname=acosta_flores_hernandez_porretti_db1 host=localhost sslmode=disable"

	reader := bufio.NewReader(os.Stdin)

	for {
		db, err := sql.Open("postgres", connStr)
		check(err, "conectando a la base")
		defer db.Close()
		fmt.Println("\n### Menú ###")
		fmt.Println("1 Crear base de datos")
		fmt.Println("2 Crear tablas")
		fmt.Println("3 Agregar PKs y FKs")
		fmt.Println("4 Eliminar PKs y FKs")
		fmt.Println("5 Cargar datos desde JSON")
		fmt.Println("6 Crear stored procedures y triggers")
		fmt.Println("7 Iniciar pruebas")
		fmt.Println("8 Cargar datos en BoltDB")
		fmt.Println("9 Mostrar datos de BoltDB")
		fmt.Println("0 Salir")
		fmt.Print("opción> ")

		opcion, _ := reader.ReadString('\n')
		opcion = strings.TrimSpace(opcion)

		switch opcion {
		case "1":
			crearBaseDeDatos()
		case "2":
			runSQLFile(db, "db_backup.sql")
		case "3":
			agregarClaves(db)
		case "4":
			quitarClaves(db)
		case "5":
			insertarClientes(db, "clientes.json")
			insertarPeliculas(db, "peliculas.json")
			insertarSalas(db, "salas_de_cine.json")
			insertarDatosDePrueba(db, "datos_de_prueba.json")
			fmt.Println("Carga desde JSON completa.")
		case "6":
			runSQLFile(db, "abrir_funcion.sql")
			runSQLFile(db, "trigger_envio_email.sql")
			runSQLFile(db, "anular_reserva.sql")
			runSQLFile(db, "reservar_butaca.sql")
			runSQLFile(db, "compra_butacas.sql")
			runSQLFile(db, "iniciar_pruebas.sql")
			fmt.Println("Procedimientos y triggers creados.")
		case "7":
			_, err := db.Exec("CALL procesar_datos_de_prueba()")
			check(err, "ejecutando pruebas")
			fmt.Println("Pruebas iniciadas.")
		case "8":
			if err := cargarDatosEnBoltDB(); err != nil {
			fmt.Println("Error:", err)
			}	
			fmt.Println("Datos cargados en bolt")
		case "9":
			if err := leerBoltDB("cine.db"); err != nil{
				fmt.Println("Error leyendo BoltDB", err)
			}
		case "0":
			fmt.Println("Saliendo...")
			return
		default:
			fmt.Println("Opción inválida.")
		}
	}
}

func runSQLFile(db *sql.DB, path string) {
	sqlBytes, err := os.ReadFile(path)
	check(err, "Leyendo archivo "+path)

	sqlText := string(sqlBytes)

	_, err = db.Exec(sqlText)
	check(err, "Ejecutando archivo "+path)

	fmt.Println("Archivo ejecutado correctamente:", path)
}
 
func crearBaseDeDatos() {
	connStr := "user=postgres dbname=postgres sslmode=disable"
	db, err := sql.Open("postgres", connStr)
	check( err, "Conexion fallida:")
	defer db.Close()

	_, err = db.Exec("DROP DATABASE IF EXISTS acosta_flores_hernandez_porretti_db1;")
	check(err, "Error al eliminar DB:")
	
	_, err = db.Exec("CREATE DATABASE acosta_flores_hernandez_porretti_db1;")
	check(err, "Error al crear DB:")
	fmt.Println("Base de datos creada!")
}

func agregarClaves(db *sql.DB) {
	querys := []string{
		// agregamos UNIQUE necesario para FK
		`ALTER TABLE public.cliente ADD CONSTRAINT cliente_email_uk UNIQUE (email);`,

		// agregamos las PKs
		`ALTER TABLE public.cliente ADD CONSTRAINT cliente_pk PRIMARY KEY (id_cliente);`,
		`ALTER TABLE public.envio_email ADD CONSTRAINT envio_email_pk PRIMARY KEY (id_email);`,
		`ALTER TABLE public.error ADD CONSTRAINT error_pk PRIMARY KEY (id_error);`,
		`ALTER TABLE public.funcion ADD CONSTRAINT funcion_pk PRIMARY KEY (id_funcion);`,
		`ALTER TABLE public.pelicula ADD CONSTRAINT pelicula_pk PRIMARY KEY (id_pelicula);`,
		`ALTER TABLE public.sala_cine ADD CONSTRAINT sala_cine_pk PRIMARY KEY (id_sala);`,

		// agregamos las FKs
		`ALTER TABLE  public.funcion
			ADD CONSTRAINT funcion_sala_fk FOREIGN KEY (id_sala) REFERENCES sala_cine(id_sala),
			ADD CONSTRAINT funcion_pelicula_fk FOREIGN KEY (id_pelicula) REFERENCES pelicula(id_pelicula);`,

		`ALTER TABLE  public.butaca_por_funcion
			ADD CONSTRAINT bpf_funcion_fk FOREIGN KEY (id_funcion) REFERENCES funcion(id_funcion),
			ADD CONSTRAINT bpf_cliente_fk FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente);`,

		`ALTER TABLE  public.envio_email
			ADD CONSTRAINT envio_email_cliente_fk FOREIGN KEY (email_cliente) REFERENCES cliente(email);`,

		`ALTER TABLE  public.error
			ADD CONSTRAINT error_sala_fk FOREIGN KEY (id_sala) REFERENCES sala_cine(id_sala),
			ADD CONSTRAINT error_cliente_fk FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente),
			ADD CONSTRAINT error_pelicula_fk FOREIGN KEY (id_pelicula) REFERENCES pelicula(id_pelicula);`,
	}
	
	for _, stmt := range querys {
		_, err := db.Exec(stmt)
		check(err, "agregando PK o FK:\n"+stmt)
	}

	fmt.Println("Claves primarias y foráneas agregadas correctamente.")
}

func quitarClaves(db *sql.DB) {
	querys := []string{
		// quitamos las FKs
		`ALTER TABLE  public.funcion
			DROP CONSTRAINT IF EXISTS funcion_sala_fk,
			DROP CONSTRAINT IF EXISTS funcion_pelicula_fk;`,

		`ALTER TABLE  public.butaca_por_funcion
			DROP CONSTRAINT IF EXISTS bpf_funcion_fk,
			DROP CONSTRAINT IF EXISTS bpf_cliente_fk;`,

		`ALTER TABLE  public.envio_email
			DROP CONSTRAINT IF EXISTS envio_email_cliente_fk;`,

		`ALTER TABLE  public.error
			DROP CONSTRAINT IF EXISTS error_sala_fk,
			DROP CONSTRAINT IF EXISTS error_cliente_fk,
			DROP CONSTRAINT IF EXISTS error_pelicula_fk;`,

		// quitamos las PKs
		`ALTER TABLE  public.cliente DROP CONSTRAINT IF EXISTS cliente_pk;`,
		`ALTER TABLE  public.envio_email DROP CONSTRAINT IF EXISTS envio_email_pk;`,
		`ALTER TABLE  public.error DROP CONSTRAINT IF EXISTS error_pk;`,
		`ALTER TABLE  public.funcion DROP CONSTRAINT IF EXISTS funcion_pk;`,
		`ALTER TABLE  public.pelicula DROP CONSTRAINT IF EXISTS pelicula_pk;`,
		`ALTER TABLE  public.sala_cine DROP CONSTRAINT IF EXISTS sala_cine_pk;`,

		// quitamos UNIQUE
		`ALTER TABLE  public.cliente DROP CONSTRAINT IF EXISTS cliente_email_uk;`,
	}

	for _, stmt := range querys {
		_, err := db.Exec(stmt)
		check(err, "quitando PK o FK:\n"+stmt)
	}

	fmt.Println("Claves primarias y foráneas eliminadas correctamente.")
}

func insertarClientes(db *sql.DB, ruta string) {
	f := abrirArchivo(ruta)
	defer f.Close()

	var clientes []Cliente
	decodeJSON(f, &clientes)

	stmt := `
	  INSERT INTO cliente (
	    id_cliente, nombre, apellido, dni, fecha_nacimiento, telefono, email
	  ) VALUES ($1,$2,$3,$4,$5,$6,$7)
	  ON CONFLICT (id_cliente) DO NOTHING;`

	for _, c := range clientes {
		fecha, err := time.Parse("2006-01-02", c.FechaNacimiento)
		check(err, "parseando fecha cliente")

		_, err = db.Exec(stmt,
			c.IDCliente, c.Nombre, c.Apellido, c.DNI,
			fecha, c.Telefono, c.Email)
		check(err, "insertando cliente")
	}
}

func insertarPeliculas(db *sql.DB, ruta string) {
	f := abrirArchivo(ruta)
	defer f.Close()

	var pelis []Pelicula
	decodeJSON(f, &pelis)

	stmt := `
	  INSERT INTO pelicula (
	    id_pelicula, titulo, duracion, director, origen, formato
	  ) VALUES ($1,$2,$3::interval,$4,$5,$6)
	  ON CONFLICT (id_pelicula) DO NOTHING;`

	for _, p := range pelis {
		_, err := db.Exec(stmt,
			p.ID, p.Titulo, p.Duracion,
			p.Director, p.Origen, p.Formato)
		check(err, "insertando pelicula")
	}
}

func insertarSalas(db *sql.DB, ruta string) {
	f := abrirArchivo(ruta)
	defer f.Close()

	var salas []SalaCine
	decodeJSON(f, &salas)

	stmt := `
	  INSERT INTO sala_cine (
	    id_sala, nombre, formato, nro_filas,
	    nro_butacas_por_fila, capacidad_total
	  ) VALUES ($1,$2,$3,$4,$5,$6)
	  ON CONFLICT (id_sala) DO NOTHING;`

	for _, s := range salas {
		capacidad := s.NroFilas * s.NroButacasPorFila
		_, err := db.Exec(stmt,
			s.IDSala, s.Nombre, s.Formato,
			s.NroFilas, s.NroButacasPorFila, capacidad)
		check(err, "insertando sala")
	}
}

func cargarDatosEnBoltDB() error {
	clientes := cargarJSONClientes("clientes.json")
	salas := cargarJSONSalas("salas_de_cine.json")
	peliculas := cargarJSONPeliculas("peliculas.json")
	ordenes := cargarJSONOrdenes("datos_de_prueba.json")

	db, err := bbolt.Open("cine.db", 0600, nil)
	if err != nil {
		return err
	}
	defer db.Close()

	db.Update(func(tx *bbolt.Tx) error {
		buckets := []string{"clientes", "salas", "peliculas", "funciones", "butacas"}
		for _, bucket := range buckets {
			tx.CreateBucketIfNotExists([]byte(bucket))
		}

		for _, c := range clientes {
			guardar(tx, "clientes", fmt.Sprintf("%d", c.IDCliente), c)
		}
		for _, s := range salas {
			guardar(tx, "salas", fmt.Sprintf("%d", s.IDSala), s)
		}
		for _, p := range peliculas {
			guardar(tx, "peliculas", fmt.Sprintf("%d", p.ID), p)
		}
		funciones := map[int]bool{}
		butacas := 0
		for _, o := range ordenes {
			if o.IDFuncion != 0 && !funciones[o.IDFuncion] {
				funciones[o.IDFuncion] = true
				guardar(tx, "funciones", fmt.Sprintf("%d", o.IDFuncion), o)
			}
			if o.NroButaca != 0 && o.NroFila != 0 {
				clave := fmt.Sprintf("%d_%d_%d", o.IDFuncion, o.NroFila, o.NroButaca)
				guardar(tx, "butacas", clave, o)
				butacas++
			}
		}
		return nil
	})
	return nil
}

func guardar(tx *bbolt.Tx, bucket string, clave string, dato any) {
	b := tx.Bucket([]byte(bucket))
	raw, _ := json.Marshal(dato)
	b.Put([]byte(clave), raw)
}

func cargarJSONClientes(path string) []Cliente {
	var datos []Cliente
	cargarJSON(path, &datos)
	return datos
}

func cargarJSONSalas(path string) []SalaCine {
	var datos []SalaCine
	cargarJSON(path, &datos)
	return datos
}

func cargarJSONPeliculas(path string) []Pelicula {
	var datos []Pelicula
	cargarJSON(path, &datos)
	return datos
}

func cargarJSONOrdenes(path string) []OrdenPrueba {
	var datos []OrdenPrueba
	cargarJSON(path, &datos)
	return datos
}

func cargarJSON(path string, destino any) {
	data, err := os.ReadFile(path)
	if err != nil {
		log.Fatal(err)
	}
	err = json.Unmarshal(data, destino)
	if err != nil {
		log.Fatal(err)
	}
}


func insertarDatosDePrueba(db *sql.DB, ruta string) {
    f := abrirArchivo(ruta)
    defer f.Close()

    var ordenes []OrdenPrueba
    decodeJSON(f, &ordenes)

    const tsLayout = "2006-01-02 15:04"

    stmt := `
      INSERT INTO datos_de_prueba (
        id_orden, operacion, id_sala, f_inicio_funcion,
        id_pelicula, id_funcion, nro_fila, nro_butaca, id_cliente
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
      ON CONFLICT (id_orden) DO NOTHING;`

    for _, o := range ordenes {
        var tsPtr *time.Time
        if o.FInicio != "" {
            t, err := time.Parse(tsLayout, o.FInicio)
            check(err, "parseando f_inicio en datos_deprueba")
            tsPtr = &t
        }

        _, err := db.Exec(stmt,
            o.IDOrden,
            o.Operacion,
            o.IDSala,
            tsPtr,
            o.IDPelicula,
            o.IDFuncion,
            o.NroFila,
            o.NroButaca,
            o.IDCliente,
        )
        check(err, "insertando datos_de_prueba")
    }
}


func abrirArchivo(path string) *os.File {
	f, err := os.Open(path)
	check(err, "abriendo "+path)
	return f
}

func decodeJSON(f *os.File, v any) {
	err := json.NewDecoder(f).Decode(v)
	check(err, "decodificando JSON")
}

func check(err error, contexto string) {
	if err != nil {
		log.Fatalf("%s: %v", contexto, err)
	}
}

func leerBoltDB(path string) error {
    db, err := bbolt.Open(path, 0600, nil)
    check(err, "abriendo BoltDB")
    defer db.Close()

    buckets := []string{"clientes", "salas", "peliculas", "funciones", "butacas"}

    return db.View(func(tx *bbolt.Tx) error {
        for _,bucketName := range buckets {
            b := tx.Bucket([]byte(bucketName))
            if b == nil {
                fmt.Printf("Bucket %s no existe\n", bucketName)
                continue
            }

            fmt.Printf("Bucket: %s\n", bucketName)

            err := b.ForEach(func(k, v []byte) error {
                var m map[string]any
                if err := json.Unmarshal(v, &m); err != nil {
                    fmt.Printf("Error al leer la clave %s: %v\n", k, err)
                    return nil 
                }

                pretty, _ := json.MarshalIndent(m, "", "  ")
                fmt.Printf("key = %s\n%s\n\n", k, pretty)
                return nil
            })
            if err != nil {
                fmt.Printf("Error al leer bucket %s: %v\n", bucketName, err)
            }
        }
        return nil
    })
}




