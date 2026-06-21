/*

    Muhammad Taufiqul Hafizh (255150207111017)

*/

package sim.farmbtn_apps;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import javax.swing.JOptionPane;
import javax.swing.table.DefaultTableModel;
import java.awt.Color; 

public class Form_InputTelur extends javax.swing.JFrame {
    private Connection conn;
    private final DefaultTableModel tableModel;
    private static final String DB_URL = "jdbc:sqlserver://localhost:1433;databaseName=SIM_FARM_BTN;encrypt=true;trustServerCertificate=true;";
    private static final String DB_USER = "sa"; 
    private static final String DB_PASS = "admin1234"; 
    private static final java.util.logging.Logger logger = java.util.logging.Logger.getLogger(Form_InputTelur.class.getName());

    /**
     * form input dari baris pilihan di tabel
     */
    private void fillFieldsFromTable() {
        int row = jTblPanen.getSelectedRow();
        if (row == -1) return;
        
        // Index digeser +1 karena kolom 0 adalah ID (Hidden)
        isiTanggal.setText(jTblPanen.getValueAt(row, 2).toString());
        
        String namaKandang = jTblPanen.getValueAt(row, 3).toString();
        for (int i = 0; i < jboxKandang.getItemCount(); i++) {
            if (jboxKandang.getItemAt(i).startsWith(namaKandang)) {
                jboxKandang.setSelectedIndex(i);
                break;
            }
        }
        
        String grade = jTblPanen.getValueAt(row, 4).toString();
        for (int i = 0; i < jboxGrade.getItemCount(); i++) {
            if (jboxGrade.getItemAt(i).equals(grade)) {
                jboxGrade.setSelectedIndex(i);
                break;
            }
        }
        
        isiButir.setText(jTblPanen.getValueAt(row, 5).toString());
        isiBerat.setText(jTblPanen.getValueAt(row, 6).toString());
    }
    
    public Form_InputTelur() {
        initComponents();
        getContentPane().setBackground(new Color(204,234,255));
        jPanel1.setBackground(Color.WHITE); 
        jPanel2.setBackground(Color.WHITE);

        tableModel = (DefaultTableModel) jTblPanen.getModel();
        tableModel.setRowCount(0);
        jboxGrade.setModel(new javax.swing.DefaultComboBoxModel<>(new String[] { "A", "B", "C", "Pecah/Afkir" }));
        
        jTblPanen.getColumnModel().getColumn(0).setMaxWidth(0);
        jTblPanen.getColumnModel().getColumn(0).setMinWidth(0);
        jTblPanen.getColumnModel().getColumn(0).setWidth(0);
        jTblPanen.getColumnModel().getColumn(0).setPreferredWidth(0); 
        
        jTblPanen.getSelectionModel().addListSelectionListener(e -> {
            if (!e.getValueIsAdjusting()) {
                fillFieldsFromTable();
            }
        });
    }
    
    private void connectDatabase() {
        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
            conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS);
            JOptionPane.showMessageDialog(this, "Koneksi Database Berhasil!");
            
            loadPanenData();
            loadKandangToComboBox();
            loadKaryawanToComboBox();
            
        } catch (ClassNotFoundException | SQLException e) {
            JOptionPane.showMessageDialog(this, "Koneksi Gagal: " + e.getMessage());
            logger.log(java.util.logging.Level.SEVERE, null, e);
        }
    }

    private void loadPanenData() {
        tableModel.setRowCount(0);
        
        String sql = "SELECT p.panen_id, p.panen_tanggal, k.nama_kandang, " +
                     "p.grade_telur, p.jumlah_butir, p.berat_kg " +
                     "FROM panen_telur p " +
                     "JOIN batch b ON p.batch_id = b.batch_id " +
                     "JOIN kandang k ON b.kandang_id = k.kandang_id " +
                     "ORDER BY p.panen_tanggal DESC";
        
        try (Statement stmt = conn.createStatement(); 
             ResultSet rs = stmt.executeQuery(sql)) {
            
            int no = 1;
            while (rs.next()) {
                tableModel.addRow(new Object[]{
                    rs.getInt("panen_id"),
                    no++,                  
                    rs.getString("panen_tanggal"),
                    rs.getString("nama_kandang"),
                    rs.getString("grade_telur"),
                    rs.getInt("jumlah_butir"),
                    rs.getDouble("berat_kg")
                });
            }
        } catch (SQLException e) {
            JOptionPane.showMessageDialog(this, "Error Load Data: " + e.getMessage());
        }
    }
    
    private void loadKandangToComboBox() {
        jboxKandang.removeAllItems();
        try (Statement stmt = conn.createStatement(); 
             ResultSet rs = stmt.executeQuery("SELECT kandang_id, nama_kandang FROM kandang ORDER BY nama_kandang")) {
            while (rs.next()) {
                jboxKandang.addItem(rs.getString("nama_kandang") + "|" + rs.getInt("kandang_id"));
            }
        } catch (SQLException e) {
            JOptionPane.showMessageDialog(this, "Error Load Kandang: " + e.getMessage());
        }
    }

    private void loadKaryawanToComboBox() {
        jboxKaryawan.removeAllItems();
        try (Statement stmt = conn.createStatement(); 
             ResultSet rs = stmt.executeQuery(
                 "SELECT karyawan_id, nama_karyawan FROM karyawan WHERE peran_karyawan='Mandor' ORDER BY nama_karyawan")) {
            while (rs.next()) {
                jboxKaryawan.addItem("Mandor - " + rs.getString("nama_karyawan") + "|" + rs.getInt("karyawan_id"));
            }
        } catch (SQLException e) {
            JOptionPane.showMessageDialog(this, "Error Load Karyawan: " + e.getMessage());
        }
    }

    private void addPanen() {
        if (conn == null) {
            JOptionPane.showMessageDialog(this, "Hubungkan database terlebih dahulu!");
            return;
        }

        if (isiTanggal.getText().trim().isEmpty() || isiButir.getText().trim().isEmpty() || isiBerat.getText().trim().isEmpty()) {
            JOptionPane.showMessageDialog(this, "Semua field wajib diisi!");
            return;
        }

        try {
            Integer.valueOf(isiButir.getText().trim());
            Double.valueOf(isiBerat.getText().trim());
        } catch (NumberFormatException e) {
            JOptionPane.showMessageDialog(this, "Jumlah dan Berat harus berupa angka!");
            return;
        }

        String[] kandangParts = ((String) jboxKandang.getSelectedItem()).split("\\|");
        int kandangId = Integer.parseInt(kandangParts[1]);
        
        String[] karyawanParts = ((String) jboxKaryawan.getSelectedItem()).split("\\|");
        int karyawanId = Integer.parseInt(karyawanParts[1]);
        
        String grade = (String) jboxGrade.getSelectedItem();
        String tanggal = isiTanggal.getText().trim();

        int batchId = 0;
        try (PreparedStatement pstBatch = conn.prepareStatement(
                "SELECT TOP 1 batch_id FROM batch WHERE kandang_id = ? AND tanggal_selesai IS NULL ORDER BY tanggal_mulai DESC")) {
            pstBatch.setInt(1, kandangId);
            ResultSet rs = pstBatch.executeQuery();
            if (rs.next()) batchId = rs.getInt("batch_id");
            else {
                JOptionPane.showMessageDialog(this, "Tidak ada batch aktif untuk kandang ini!");
                return;
            }
        } catch (SQLException e) {
            JOptionPane.showMessageDialog(this, "Error Cek Batch: " + e.getMessage());
            return;
        }

        String sql = "INSERT INTO panen_telur (batch_id, panen_tanggal, grade_telur, jumlah_butir, berat_kg, karyawan_id) VALUES (?, ?, ?, ?, ?, ?)";
        try (PreparedStatement pst = conn.prepareStatement(sql)) {
            pst.setInt(1, batchId);
            pst.setString(2, tanggal);
            pst.setString(3, grade);
            pst.setInt(4, Integer.parseInt(isiButir.getText().trim()));
            pst.setDouble(5, Double.parseDouble(isiBerat.getText().trim()));
            pst.setInt(6, karyawanId);
            
            pst.executeUpdate();
            JOptionPane.showMessageDialog(this, "Data Panen Berhasil Ditambahkan!");
            loadPanenData();
            clearForm();
        } catch (SQLException e) {
            JOptionPane.showMessageDialog(this, "Error Insert: " + e.getMessage());
        }
    }

    private void clearForm() {
        isiTanggal.setText("");
        isiButir.setText("");
        isiBerat.setText("");
        if (jboxKandang.getItemCount() > 0) jboxKandang.setSelectedIndex(0);
        if (jboxGrade.getItemCount() > 0) jboxGrade.setSelectedIndex(0);
        if (jboxKaryawan.getItemCount() > 0) jboxKaryawan.setSelectedIndex(0);
    }
    
    @SuppressWarnings("unchecked")
    // <editor-fold defaultstate="collapsed" desc="Generated Code">//GEN-BEGIN:initComponents
    private void initComponents() {

        judulApps = new javax.swing.JLabel();
        BtnKoneksi = new javax.swing.JButton();
        jPanel1 = new javax.swing.JPanel();
        jdlForm = new javax.swing.JLabel();
        isiTanggal = new javax.swing.JTextField();
        FormatTgl = new javax.swing.JLabel();
        jdlKandang = new javax.swing.JLabel();
        jboxKandang = new javax.swing.JComboBox<>();
        jGrade = new javax.swing.JLabel();
        jboxGrade = new javax.swing.JComboBox<>();
        jLabel1 = new javax.swing.JLabel();
        isiButir = new javax.swing.JTextField();
        FormatButir = new javax.swing.JLabel();
        jdlBerat = new javax.swing.JLabel();
        isiBerat = new javax.swing.JTextField();
        jdlKaryawan = new javax.swing.JLabel();
        jboxKaryawan = new javax.swing.JComboBox<>();
        BtnAdd = new javax.swing.JButton();
        BtnuUpdate = new javax.swing.JButton();
        BtnDel = new javax.swing.JButton();
        jPanel2 = new javax.swing.JPanel();
        jdlPanen = new javax.swing.JLabel();
        jScrollPane1 = new javax.swing.JScrollPane();
        jTblPanen = new javax.swing.JTable();

        setDefaultCloseOperation(javax.swing.WindowConstants.EXIT_ON_CLOSE);
        setTitle("SIM-FARM BTN - [Modul Panen Telur]");
        setAutoRequestFocus(false);
        setBackground(new java.awt.Color(204, 234, 255));

        judulApps.setFont(new java.awt.Font("Lucida Sans", 1, 30)); // NOI18N
        judulApps.setText("Aplikasi Manajemen Farm - Berkah Telur Nusantara (BTN)");

        BtnKoneksi.setFont(new java.awt.Font("Microsoft Sans Serif", 1, 12)); // NOI18N
        BtnKoneksi.setText("Koneksi");
        BtnKoneksi.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                BtnKoneksiActionPerformed(evt);
            }
        });

        jPanel1.setBackground(new java.awt.Color(204, 234, 255));
        jPanel1.setBorder(javax.swing.BorderFactory.createEtchedBorder(new java.awt.Color(204, 204, 204), null));

        jdlForm.setFont(new java.awt.Font("Lucida Sans Unicode", 1, 24)); // NOI18N
        jdlForm.setText("Form Input Panen");

        FormatTgl.setForeground(new java.awt.Color(255, 0, 0));
        FormatTgl.setText("* Format tanggal YYYY-MM-DD");

        jdlKandang.setText("Kandang");

        jboxKandang.setModel(new javax.swing.DefaultComboBoxModel<>(new String[] { "Item 1", "Item 2", "Item 3", "Item 4" }));
        jboxKandang.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                jboxKandangActionPerformed(evt);
            }
        });

        jGrade.setText("Kategori Telur (Grade)");

        jboxGrade.setModel(new javax.swing.DefaultComboBoxModel<>(new String[] { "Item 1", "Item 2", "Item 3", "Item 4" }));
        jboxGrade.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                jboxGradeActionPerformed(evt);
            }
        });

        jLabel1.setText("Jumlah (Burtir)");

        isiButir.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                isiButirActionPerformed(evt);
            }
        });

        FormatButir.setForeground(new java.awt.Color(255, 0, 0));
        FormatButir.setText("* Jumlah harus berupa angka");

        jdlBerat.setText("Berat Total (Kg)");

        isiBerat.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                isiBeratActionPerformed(evt);
            }
        });

        jdlKaryawan.setText("Karyawan");

        jboxKaryawan.setModel(new javax.swing.DefaultComboBoxModel<>(new String[] { "Item 1", "Item 2", "Item 3", "Item 4" }));

        BtnAdd.setFont(new java.awt.Font("Microsoft Sans Serif", 1, 12)); // NOI18N
        BtnAdd.setText("Tambah");
        BtnAdd.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                BtnAddActionPerformed(evt);
            }
        });

        BtnuUpdate.setFont(new java.awt.Font("Microsoft Sans Serif", 1, 12)); // NOI18N
        BtnuUpdate.setText("Ubah");
        BtnuUpdate.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                BtnuUpdateActionPerformed(evt);
            }
        });

        BtnDel.setFont(new java.awt.Font("MS Reference Sans Serif", 1, 12)); // NOI18N
        BtnDel.setText("Hapus");
        BtnDel.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                BtnDelActionPerformed(evt);
            }
        });

        javax.swing.GroupLayout jPanel1Layout = new javax.swing.GroupLayout(jPanel1);
        jPanel1.setLayout(jPanel1Layout);
        jPanel1Layout.setHorizontalGroup(
            jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(jPanel1Layout.createSequentialGroup()
                .addContainerGap()
                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                    .addComponent(jboxKandang, javax.swing.GroupLayout.PREFERRED_SIZE, 302, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                        .addComponent(jdlKandang)
                        .addComponent(jLabel1)
                        .addGroup(jPanel1Layout.createSequentialGroup()
                            .addComponent(jGrade)
                            .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                            .addComponent(jboxGrade, javax.swing.GroupLayout.PREFERRED_SIZE, 180, javax.swing.GroupLayout.PREFERRED_SIZE))
                        .addComponent(jdlBerat)
                        .addComponent(jdlKaryawan)
                        .addComponent(jdlForm)
                        .addGroup(jPanel1Layout.createSequentialGroup()
                            .addGap(6, 6, 6)
                            .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                .addComponent(FormatButir)
                                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                                    .addGroup(jPanel1Layout.createSequentialGroup()
                                        .addComponent(BtnAdd, javax.swing.GroupLayout.PREFERRED_SIZE, 87, javax.swing.GroupLayout.PREFERRED_SIZE)
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addComponent(BtnuUpdate, javax.swing.GroupLayout.PREFERRED_SIZE, 116, javax.swing.GroupLayout.PREFERRED_SIZE)
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addComponent(BtnDel, javax.swing.GroupLayout.PREFERRED_SIZE, 87, javax.swing.GroupLayout.PREFERRED_SIZE))
                                    .addComponent(isiTanggal)
                                    .addComponent(FormatTgl)
                                    .addComponent(isiButir)
                                    .addComponent(isiBerat)
                                    .addComponent(jboxKaryawan, 0, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))))))
                .addContainerGap(16, Short.MAX_VALUE))
        );
        jPanel1Layout.setVerticalGroup(
            jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(jPanel1Layout.createSequentialGroup()
                .addGap(12, 12, 12)
                .addComponent(jdlForm, javax.swing.GroupLayout.PREFERRED_SIZE, 31, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.UNRELATED)
                .addComponent(isiTanggal, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(FormatTgl)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(jdlKandang)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(jboxKandang, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                    .addComponent(jboxGrade, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(jGrade))
                .addGap(34, 34, 34)
                .addComponent(jLabel1)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(isiButir, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(FormatButir)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.UNRELATED)
                .addComponent(jdlBerat)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(isiBerat, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addGap(18, 18, 18)
                .addComponent(jdlKaryawan)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(jboxKaryawan, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addGap(18, 18, 18)
                .addGroup(jPanel1Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                    .addComponent(BtnAdd)
                    .addComponent(BtnuUpdate)
                    .addComponent(BtnDel))
                .addContainerGap(javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
        );

        jPanel2.setBackground(new java.awt.Color(204, 234, 255));
        jPanel2.setBorder(javax.swing.BorderFactory.createEtchedBorder(new java.awt.Color(204, 204, 204), null));

        jdlPanen.setFont(new java.awt.Font("Lucida Sans", 1, 24)); // NOI18N
        jdlPanen.setText("Daftar Panen Hari ini");

        jTblPanen.setModel(new javax.swing.table.DefaultTableModel(
            new Object [][] {
                {null, null, null, null, null, null, null},
                {null, null, null, null, null, null, null},
                {null, null, null, null, null, null, null},
                {null, null, null, null, null, null, null},
                {null, null, null, null, null, null, null},
                {null, null, null, null, null, null, null},
                {null, null, null, null, null, null, null}
            },
            new String [] {
                "ID", "No", "Tanggal", "Kandang", "Grade", "Jumlah (Butir)", "Berat (Kg) "
            }
        ) {
            Class[] types = new Class [] {
                java.lang.Object.class, java.lang.Integer.class, java.lang.String.class, java.lang.String.class, java.lang.String.class, java.lang.String.class, java.lang.Object.class
            };
            boolean[] canEdit = new boolean [] {
                false, false, false, false, false, false, false
            };

            public Class getColumnClass(int columnIndex) {
                return types [columnIndex];
            }

            public boolean isCellEditable(int rowIndex, int columnIndex) {
                return canEdit [columnIndex];
            }
        });
        jTblPanen.getTableHeader().setReorderingAllowed(false);
        jScrollPane1.setViewportView(jTblPanen);
        if (jTblPanen.getColumnModel().getColumnCount() > 0) {
            jTblPanen.getColumnModel().getColumn(0).setResizable(false);
            jTblPanen.getColumnModel().getColumn(0).setPreferredWidth(5);
            jTblPanen.getColumnModel().getColumn(1).setResizable(false);
            jTblPanen.getColumnModel().getColumn(1).setPreferredWidth(5);
            jTblPanen.getColumnModel().getColumn(2).setResizable(false);
            jTblPanen.getColumnModel().getColumn(3).setResizable(false);
            jTblPanen.getColumnModel().getColumn(4).setResizable(false);
            jTblPanen.getColumnModel().getColumn(5).setResizable(false);
            jTblPanen.getColumnModel().getColumn(6).setResizable(false);
        }

        javax.swing.GroupLayout jPanel2Layout = new javax.swing.GroupLayout(jPanel2);
        jPanel2.setLayout(jPanel2Layout);
        jPanel2Layout.setHorizontalGroup(
            jPanel2Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(jPanel2Layout.createSequentialGroup()
                .addContainerGap()
                .addGroup(jPanel2Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(jPanel2Layout.createSequentialGroup()
                        .addComponent(jdlPanen)
                        .addGap(0, 0, Short.MAX_VALUE))
                    .addComponent(jScrollPane1))
                .addContainerGap())
        );
        jPanel2Layout.setVerticalGroup(
            jPanel2Layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(jPanel2Layout.createSequentialGroup()
                .addGap(14, 14, 14)
                .addComponent(jdlPanen)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                .addComponent(jScrollPane1, javax.swing.GroupLayout.PREFERRED_SIZE, 421, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addContainerGap())
        );

        javax.swing.GroupLayout layout = new javax.swing.GroupLayout(getContentPane());
        getContentPane().setLayout(layout);
        layout.setHorizontalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(layout.createSequentialGroup()
                .addContainerGap()
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(layout.createSequentialGroup()
                        .addComponent(jPanel1, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.UNRELATED)
                        .addComponent(jPanel2, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                    .addGroup(layout.createSequentialGroup()
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(BtnKoneksi)
                            .addComponent(judulApps))
                        .addGap(0, 121, Short.MAX_VALUE)))
                .addContainerGap())
        );
        layout.setVerticalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(layout.createSequentialGroup()
                .addContainerGap()
                .addComponent(judulApps, javax.swing.GroupLayout.PREFERRED_SIZE, 63, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(BtnKoneksi)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.UNRELATED)
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(jPanel1, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .addComponent(jPanel2, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                .addContainerGap())
        );

        pack();
    }// </editor-fold>//GEN-END:initComponents
        
    private void jboxKandangActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_jboxKandangActionPerformed
        // TODO add your handling code here:
    }//GEN-LAST:event_jboxKandangActionPerformed

    private void jboxGradeActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_jboxGradeActionPerformed
        // TODO add your handling code here:
    }//GEN-LAST:event_jboxGradeActionPerformed

    private void isiButirActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_isiButirActionPerformed
        // TODO add your handling code here:
    }//GEN-LAST:event_isiButirActionPerformed

    private void isiBeratActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_isiBeratActionPerformed
        // TODO add your handling code here:
    }//GEN-LAST:event_isiBeratActionPerformed

    private void BtnuUpdateActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_BtnuUpdateActionPerformed
        int selectedRow = jTblPanen.getSelectedRow();
        if (selectedRow == -1) {
            JOptionPane.showMessageDialog(this, "Pilih data di tabel yang ingin diubah!");
            return;
        }

        if (isiTanggal.getText().trim().isEmpty() || isiButir.getText().trim().isEmpty() || isiBerat.getText().trim().isEmpty()) {
            JOptionPane.showMessageDialog(this, "Semua field wajib diisi!");
            return;
        }

        int panenId = Integer.parseInt(jTblPanen.getValueAt(selectedRow, 0).toString());
        
        String[] kandangParts = ((String) jboxKandang.getSelectedItem()).split("\\|");
        int kandangId = Integer.parseInt(kandangParts[1]);
        
        String[] karyawanParts = ((String) jboxKaryawan.getSelectedItem()).split("\\|");
        int karyawanId = Integer.parseInt(karyawanParts[1]);
        
        String grade = (String) jboxGrade.getSelectedItem();
        String tanggal = isiTanggal.getText().trim();

        int batchId = 0;
        try (PreparedStatement pstBatch = conn.prepareStatement(
                "SELECT TOP 1 batch_id FROM batch WHERE kandang_id = ? AND tanggal_selesai IS NULL ORDER BY tanggal_mulai DESC")) {
            pstBatch.setInt(1, kandangId);
            ResultSet rs = pstBatch.executeQuery();
            if (rs.next()) batchId = rs.getInt("batch_id");
            else {
                JOptionPane.showMessageDialog(this, "Tidak ada batch aktif untuk kandang ini!");
                return;
            }
        } catch (SQLException e) {
            JOptionPane.showMessageDialog(this, "Error Cek Batch: " + e.getMessage());
            return;
        }

        String sql = "UPDATE panen_telur SET batch_id=?, panen_tanggal=?, grade_telur=?, jumlah_butir=?, berat_kg=?, karyawan_id=? WHERE panen_id=?";
        try (PreparedStatement pst = conn.prepareStatement(sql)) {
            pst.setInt(1, batchId);
            pst.setString(2, tanggal);
            pst.setString(3, grade);
            pst.setInt(4, Integer.parseInt(isiButir.getText().trim()));
            pst.setDouble(5, Double.parseDouble(isiBerat.getText().trim()));
            pst.setInt(6, karyawanId);
            pst.setInt(7, panenId);
            
            pst.executeUpdate();
            JOptionPane.showMessageDialog(this, "Data Panen Berhasil Diubah!");
            loadPanenData();
            clearForm();
        } catch (SQLException e) {
            JOptionPane.showMessageDialog(this, "Error Update: " + e.getMessage());
        }
    }//GEN-LAST:event_BtnuUpdateActionPerformed

    private void BtnAddActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_BtnAddActionPerformed
        addPanen();
    }//GEN-LAST:event_BtnAddActionPerformed

    private void BtnDelActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_BtnDelActionPerformed
        int selectedRow = jTblPanen.getSelectedRow();
        if (selectedRow == -1) {
            JOptionPane.showMessageDialog(this, "Pilih data di tabel yang ingin dihapus!");
            return;
        }
        
        int confirm = JOptionPane.showConfirmDialog(this, 
            "Yakin hapus data panen ini?", "Konfirmasi Hapus", 
            JOptionPane.YES_NO_OPTION);
            
        if (confirm == JOptionPane.YES_OPTION) {
            int panenId = Integer.parseInt(jTblPanen.getValueAt(selectedRow, 0).toString());
            String sql = "DELETE FROM panen_telur WHERE panen_id = ?";
            try (PreparedStatement pst = conn.prepareStatement(sql)) {
                pst.setInt(1, panenId);
                pst.executeUpdate();
                JOptionPane.showMessageDialog(this, "Data berhasil dihapus!");
                loadPanenData();
                clearForm();
            } catch (SQLException e) {
                JOptionPane.showMessageDialog(this, "Error Hapus: " + e.getMessage());
            }
        }                              
    }//GEN-LAST:event_BtnDelActionPerformed

    private void BtnKoneksiActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_BtnKoneksiActionPerformed
        connectDatabase();
    }//GEN-LAST:event_BtnKoneksiActionPerformed

    public static void main(String args[]) {
        try {
            for (javax.swing.UIManager.LookAndFeelInfo info : javax.swing.UIManager.getInstalledLookAndFeels()) {
                if ("Nimbus".equals(info.getName())) {
                    javax.swing.UIManager.setLookAndFeel(info.getClassName());
                    break;
                }
            }
        } catch (ReflectiveOperationException | javax.swing.UnsupportedLookAndFeelException ex) {
            logger.log(java.util.logging.Level.SEVERE, null, ex);
        }
        java.awt.EventQueue.invokeLater(() -> new Form_InputTelur().setVisible(true));
    }

    // Variables declaration - do not modify//GEN-BEGIN:variables
    private javax.swing.JButton BtnAdd;
    private javax.swing.JButton BtnDel;
    private javax.swing.JButton BtnKoneksi;
    private javax.swing.JButton BtnuUpdate;
    private javax.swing.JLabel FormatButir;
    private javax.swing.JLabel FormatTgl;
    private javax.swing.JTextField isiBerat;
    private javax.swing.JTextField isiButir;
    private javax.swing.JTextField isiTanggal;
    private javax.swing.JLabel jGrade;
    private javax.swing.JLabel jLabel1;
    private javax.swing.JPanel jPanel1;
    private javax.swing.JPanel jPanel2;
    private javax.swing.JScrollPane jScrollPane1;
    private javax.swing.JTable jTblPanen;
    private javax.swing.JComboBox<String> jboxGrade;
    private javax.swing.JComboBox<String> jboxKandang;
    private javax.swing.JComboBox<String> jboxKaryawan;
    private javax.swing.JLabel jdlBerat;
    private javax.swing.JLabel jdlForm;
    private javax.swing.JLabel jdlKandang;
    private javax.swing.JLabel jdlKaryawan;
    private javax.swing.JLabel jdlPanen;
    private javax.swing.JLabel judulApps;
    // End of variables declaration//GEN-END:variables
}