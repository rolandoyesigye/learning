package com.example.demo.domain.entity;

import com.example.demo.domain.enums.RegStatus;
import com.example.demo.domain.enums.TxnType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.UUID;

@Entity
@Table(name = "land_registrations")
@Getter
@Setter
public class LandRegistration {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "registration_id")
    private UUID id;

    @Column(name = "reference_number", unique = true, nullable = false, length = 50)
    private String referenceNumber;

    @Enumerated(EnumType.STRING)
    @Column(name = "transaction_type", nullable = false)
    private TxnType transactionType;

    @Column(name = "transaction_date", nullable = false)
    private LocalDate transactionDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RegStatus status = RegStatus.DRAFT;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "lc1_unit_id", nullable = false)
    private AdministrativeUnit lc1Unit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parish_unit_id", nullable = false)
    private AdministrativeUnit parishUnit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "subcounty_unit_id", nullable = false)
    private AdministrativeUnit subcountyUnit;

    @Column(name = "parcel_description", columnDefinition = "TEXT")
    private String parcelDescription;

    @Column(name = "land_use_type", length = 50)
    private String landUseType;

    @Column(name = "parcel_area_sqm", precision = 14, scale = 4)
    private BigDecimal parcelAreaSqm;

    @Column(name = "parcel_area_acres", precision = 14, scale = 4)
    private BigDecimal parcelAreaAcres;

    @Column(name = "is_cross_boundary", nullable = false)
    private boolean isCrossBoundary = false;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "submitted_by_user_id", nullable = false)
    private User submittedBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parish_approved_by")
    private User parishApprovedBy;

    @Column(name = "parish_approved_at")
    private ZonedDateTime parishApprovedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "subcounty_approved_by")
    private User subcountyApprovedBy;

    @Column(name = "subcounty_approved_at")
    private ZonedDateTime subcountyApprovedAt;

    @Column(name = "rejection_reason", columnDefinition = "TEXT")
    private String rejectionReason;

    @Column(name = "offline_queued", nullable = false)
    private boolean offlineQueued = false;

    @Column(name = "device_id", length = 100)
    private String deviceId;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private ZonedDateTime createdAt;

    @Column(name = "field_created_at", nullable = false)
    private ZonedDateTime fieldCreatedAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private ZonedDateTime updatedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_user_id", nullable = false)
    private User createdBy;
}
