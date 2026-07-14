package com.example.demo.domain.entity;

import com.example.demo.domain.enums.AdminLevel;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.locationtech.jts.geom.Polygon;

import java.time.ZonedDateTime;
import java.util.UUID;

@Entity
@Table(name = "administrative_units")
@Getter
@Setter
public class AdministrativeUnit {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "unit_id")
    private UUID id;

    @Column(name = "unit_name", nullable = false, length = 200)
    private String unitName;

    @Enumerated(EnumType.STRING)
    @Column(name = "unit_type", nullable = false)
    private AdminLevel unitType;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_unit_id")
    private AdministrativeUnit parentUnit;

    @Column(name = "district_name", nullable = false, length = 100)
    private String districtName;

    @Column(name = "boundary_polygon", columnDefinition = "geometry(Polygon,4326)")
    private Polygon boundaryPolygon;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private ZonedDateTime createdAt;
}
