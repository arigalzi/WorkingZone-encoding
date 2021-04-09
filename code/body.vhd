-- Progetto Di Reti Logiche 2019/2020 Prof. Fabio Salice
-- Arianna Galzerano (MATRICOLA: 10563365)


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

---COMPONENTE---
entity project_reti_logiche is
--inserimento di due generic per permettere di estendere il numero di working zones
generic (
    ADDRESS_WITH_VALUE : std_logic_vector(15 downto 0) := "0000000000001000"; --address della RAM in cui è contenuto il valore(indirizzo) da codificare
    ADDRESS_WITH_ENCODED_VALUE : std_logic_vector(15 downto 0) := "0000000000001001" --address della RAM in cui inserire il valore(indirizzo) codificato
);
port (
    i_clk :     in std_logic;
    i_start :   in std_logic;
    i_rst :     in std_logic;
    i_data :    in std_logic_vector(7 downto 0);
    o_address:  out std_logic_vector(15 downto 0);
    o_done :    out std_logic;
    o_en :      out std_logic;
    o_we :      out std_logic;
    o_data :    out std_logic_vector(7 downto 0)
  );
end project_reti_logiche;


  architecture prlarch of project_reti_logiche is

     --STATI DELLA FSM
      type STATES is (
           S_INIT, --stato in cui attendo finchè i_start viene attivato, abilito la lettura in memoria; in caso di reset torno qui
           S_WAIT_DATA,--stato in cui attendo il valore da codificare
           S_FIRST_WZ, --stato in cui salvo il valore da codificare in una variabile e inserisco il primo address della RAM che contiene wz per leggerne il valore
           S_WAIT_WZ,--stato in cui attendo il valore della wz
           S_COMPARISON, --stato in cui avviene il confronto e , in caso di riscontro positivo sulla condizione di appartenenza a una wz, assegnamento delle parti che aandranno a comporre il dato codificato
           S_NEXT_ADDRESS_MEMORY,--stato in cui itero per andare a leggere in RAM il prossimo valore di wz
           S_ENCODING,--stato in cui avviene l'assegnamento del dato da codificare
           S_NOT_FOUND,--stato in cui si crea il dato da inserire senza svolgere alcuna codifica
           S_STORE_ENCODED_VALUE,--stato in cui salvo in memoria il valore codificato o non
           S_SET_DONE,--stato in cui abilito il segnale o_done
           S_FINAL_WAIT--stato in cui attendo finchè il segnale i_start torna a 0
       );


      signal CURRENT_STATE: STATES;

      Begin
      ---PROCESSO UNICO---
      Single_Process : process (i_clk, i_rst)

        variable data : std_logic_vector (7 downto 0) := "00000000"; --variabile utilizzata per salvare durante il processo il valore da codificare
        variable wz_bit : std_logic :='0'; --variabile utilizzata per rappresentare il primo bit del dato codificato, '1' se appartiene a una wz, '0' altrimenti
        variable wz_num : std_logic_vector (2 downto 0) := "000"; --variabile utilizzata per rappresentare i 3 bit del dato codificato che indicano il numero della wz al quale l'indirizzo appartiene
        variable wz_offset : std_logic_vector (3 downto 0) := "0000"; --variabile utilizzata per rappresentare i 4 bit del dato codificato che indicano l'offset rispetto all'indirizzo base della wz
        variable valdata, valcompare : integer range 0 to 510; --integers inseriti negli if per il confronto
        variable address : std_logic_vector(15 downto 0) := ADDRESS_WITH_VALUE; --variabile utilizzata nel process per assegnamento dell'address della RAM in cui leggere/scrivere

        begin


          if (i_rst = '1') then
              CURRENT_STATE <= S_INIT;

              o_done <= '0';
              o_data <= "00000000";
              wz_bit := '0';
              wz_num := "000";
              wz_offset := "0000";
              o_en <= '0';
              o_we <= '0';

          else
              if i_clk'event and i_clk = '0'  then

                o_address <= address;
                o_data <= data;

                case CURRENT_STATE is

                    when S_INIT => --1--
                        o_done <= '0';
                        o_en <= '0';
                        o_we <= '0';
                        o_data <= "00000000";
                        wz_bit := '0';
                        wz_num := "000";
                        wz_offset := "0000";
                        address := ADDRESS_WITH_VALUE ;
                    if i_start = '1' then CURRENT_STATE <=S_WAIT_DATA;  o_en <= '1';
                    else CURRENT_STATE <= S_INIT;
                    end if;


                    when S_WAIT_DATA => --2--

                    CURRENT_STATE <= S_FIRST_WZ;


                    when S_FIRST_WZ => --3--
                        data := i_data;
                        address := "0000000000000000";
                        o_we <= '0';
                        o_en <= '1';
                    CURRENT_STATE <= S_WAIT_WZ;


                    when S_WAIT_WZ => --4--

                    CURRENT_STATE <= S_COMPARISON;


                    when S_COMPARISON =>  --5--
                        valdata := to_integer(unsigned(data));
                        valcompare := to_integer(unsigned(i_data));

                    if (valdata = valcompare) then CURRENT_STATE <= S_ENCODING ; wz_offset := "0001";  wz_bit := '1'; wz_num := address (2 downto 0);
                    elsif (valdata = valcompare +1) then CURRENT_STATE <= S_ENCODING ; wz_offset := "0010"; wz_bit := '1'; wz_num := address (2 downto 0);
                    elsif (valdata = valcompare +2) then CURRENT_STATE <= S_ENCODING ; wz_offset := "0100";wz_bit := '1'; wz_num := address (2 downto 0);
                    elsif (valdata = valcompare +3) then CURRENT_STATE <= S_ENCODING ; wz_offset := "1000"; wz_bit := '1'; wz_num := address (2 downto 0);
                    elsif (address = (ADDRESS_WITH_VALUE-1)) then CURRENT_STATE <= S_NOT_FOUND; wz_bit := '0';wz_num := "000"; wz_offset := "0000";
                    else CURRENT_STATE <= S_NEXT_ADDRESS_MEMORY;
                    end if;


                    when S_NEXT_ADDRESS_MEMORY => --6--
                        o_we <= '0';
                        o_en <= '1';
                        address := std_logic_vector(to_unsigned(to_integer(unsigned(address))+1, 16));
                    CURRENT_STATE <= S_WAIT_WZ;


                    when S_ENCODING =>  --7--
                        data:= wz_bit & wz_num & wz_offset;
                        address := ADDRESS_WITH_ENCODED_VALUE;
                    CURRENT_STATE <= S_STORE_ENCODED_VALUE;


                    when S_NOT_FOUND =>  --8--
                        wz_bit := '0';
                        data := wz_bit & (data(6 downto 0));
                        address := ADDRESS_WITH_ENCODED_VALUE;
                    CURRENT_STATE <= S_STORE_ENCODED_VALUE;


                    when S_STORE_ENCODED_VALUE =>  --9--
                        o_we <= '1';
                        o_en <= '1';
                        address := ADDRESS_WITH_ENCODED_VALUE;
                    CURRENT_STATE <= S_SET_DONE;


                    when S_SET_DONE => --10--
                        o_done <= '1';
                    CURRENT_STATE <= S_FINAL_WAIT;


                    when S_FINAL_WAIT => --11--
                    if i_start = '0' then CURRENT_STATE <= S_INIT; o_done <= '0';
                    else CURRENT_STATE <= S_FINAL_WAIT ;
                    end if;


                    end case;
           end if;
           end if;

      end process;

    end prlarch;
