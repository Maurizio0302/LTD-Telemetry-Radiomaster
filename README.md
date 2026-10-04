# LTD DASH

Dashboard di telemetria per **EdgeTX**, sviluppata per radiocomandi **RadioMaster TX16S**.

Il progetto nasce per l'utilizzo con modelli RC, in particolare alianti, e permette di visualizzare in modo chiaro i principali dati di telemetria durante il volo.

## Caratteristiche

LTD DASH visualizza i principali dati disponibili dalla telemetria del modello, tra cui:

- Quota
- Vario
- Velocità
- Batteria
- GPS
- Qualità del collegamento radio
- Altri dati di telemetria disponibili dal ricevitore

La schermata è stata progettata per avere valori grandi e facilmente leggibili durante il volo.

## Compatibilità

Compatibile con radio EdgeTX dotate di display a colori, tra cui:

- RadioMaster TX16S MK3
- RadioMaster TX16S MK2
- RadioMaster TX15

Testato direttamente su:

- RadioMaster TX16S MK3 - EdgeTX 2.12.x
- RadioMaster TX16S MK2 - EdgeTX 2.11.x

La compatibilità con TX15 è prevista, ma non è stata ancora verificata direttamente.

I nomi dei sensori possono variare in funzione del ricevitore e del sistema di telemetria utilizzato.

## File

Il programma è composto da:

- `main.lua`
- `telemetria.lua`

È disponibile anche il pacchetto completo:

- `LTD_DASH_v1.7b.zip`

## Installazione

1. Scaricare `LTD_DASH_v1.7b.zip`.
2. Estrarre i due file:
   - `main.lua`
   - `telemetria.lua`
3. Copiare i file nella cartella dello script/widget sulla scheda SD della RadioMaster.
4. Avviare la radio.
5. Aggiungere LTD DASH a una schermata di telemetria di EdgeTX.

## Versione

**LTD DASH v1.7b**

Versione stabile.

## Autore

Maurizio Saracco  
Lucca Delta Team
Italy

## Note

Il progetto è in continua evoluzione.

Prima dell'utilizzo in volo è consigliato verificare a terra il corretto riconoscimento dei sensori e dei valori di telemetria.
